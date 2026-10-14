'use strict';

const http = require('http');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { Store } = require('./store');
const { PrinterEmulator } = require('./printer');
const { nextSample } = require('./samples');
const print = require('./print');

const ROOT = path.join(__dirname, '..');
const PUBLIC = path.join(ROOT, 'public');
const DATA = process.env.KDS_DATA_DIR || path.join(ROOT, 'data');

const store = new Store(DATA);
if (process.env.KDS_PRINTER_PORT) store.settings.port = Number(process.env.KDS_PRINTER_PORT);
if (process.env.KDS_WEB_PORT) store.settings.webPort = Number(process.env.KDS_WEB_PORT);

const printer = new PrinterEmulator(store);
printer.start();

// Server-sent events: every open screen gets the full picture whenever anything changes.
const clients = new Set();

function state() {
  const { active, done } = store.snapshot();
  return {
    active,
    done,
    settings: store.settings,
    logos: logoInfo(),
    lastPrint,
    status: { ...printer.status, ips: localIps() },
    serverTime: new Date().toISOString(),
  };
}

// ---------- Venue logo (top bar only; the app icon stays CTpos) ----------
// One image for dark mode and one for light mode, kept in the data folder.
const LOGO_TYPES = { png: 'image/png', jpg: 'image/jpeg', webp: 'image/webp', gif: 'image/gif' };
let logoVersion = Date.now();

/** Recognises an image by its first bytes, so a renamed file of another kind is refused. */
function imageKind(buf) {
  if (buf.length > 8 && buf.readUInt32BE(0) === 0x89504e47) return 'png';
  if (buf.length > 3 && buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff) return 'jpg';
  if (buf.length > 12 && buf.toString('ascii', 0, 4) === 'RIFF' && buf.toString('ascii', 8, 12) === 'WEBP') return 'webp';
  if (buf.length > 6 && buf.toString('ascii', 0, 4) === 'GIF8') return 'gif';
  return null;
}

function logoFile(mode) {
  for (const ext of Object.keys(LOGO_TYPES)) {
    const f = path.join(DATA, `logo-${mode}.${ext}`);
    if (fs.existsSync(f)) return { file: f, type: LOGO_TYPES[ext] };
  }
  return null;
}

function removeLogo(mode) {
  for (const ext of Object.keys(LOGO_TYPES)) {
    const f = path.join(DATA, `logo-${mode}.${ext}`);
    if (fs.existsSync(f)) fs.unlinkSync(f);
  }
}

function logoInfo() {
  return { dark: !!logoFile('dark'), light: !!logoFile('light'), version: logoVersion };
}

function readRaw(req, limit) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    req.on('data', (c) => {
      size += c.length;
      if (size > limit) {
        reject(new Error('too large'));
        req.destroy();
      } else chunks.push(c);
    });
    req.on('end', () => resolve(Buffer.concat(chunks)));
    req.on('error', reject);
  });
}

let broadcastTimer = null;
function broadcast() {
  clearTimeout(broadcastTimer);
  broadcastTimer = setTimeout(() => {
    const msg = 'event: state\ndata: ' + JSON.stringify(state()) + '\n\n';
    for (const res of clients) res.write(msg);
  }, 30);
}

// ---------- Physical printer ----------
let lastPrint = null; // { ok, at, error, what }

/** True when host:port is this device's own emulated printer, which would print in a loop. */
function isSelf(host, port) {
  if (port !== store.settings.port) return false;
  const h = String(host).trim().toLowerCase();
  if (h === 'localhost' || h.startsWith('127.') || h === '::1' || h === '0.0.0.0') return true;
  return localIps().some((i) => i.address === h);
}

async function printBytes(bytes, what) {
  const s = store.settings;
  const host = String(s.printerHost || '').trim();
  try {
    if (!host) throw new Error('Ingen printer valgt. Indtast printerens IP-adresse under Opsætning.');
    if (isSelf(host, s.printerPort)) throw new Error('Printeradressen peger på denne skærm selv. Vælg den rigtige printers IP-adresse.');
    await print.send(host, s.printerPort, bytes);
    lastPrint = { ok: true, at: new Date().toISOString(), what };
  } catch (err) {
    lastPrint = { ok: false, at: new Date().toISOString(), what, error: err.message };
    console.error('[print] ' + err.message);
  }
  broadcast();
  return lastPrint;
}

function hhmmNow() {
  const d = new Date();
  return String(d.getHours()).padStart(2, '0') + ':' + String(d.getMinutes()).padStart(2, '0');
}

store.onChange((kind, payload) => {
  if (kind === 'added' && store.settings.printerEnabled && store.settings.autoPrint) {
    printBytes(print.ticketBytes(payload.lines || []), 'Bon ' + (payload.orderNo || payload.seq));
  }
  if (kind === 'settings') {
    const { old, next } = payload;
    if (old.port !== next.port || old.bindAddress !== next.bindAddress) printer.restart();
  }
  broadcast();
});

setInterval(() => {
  for (const res of clients) res.write(': ping\n\n');
}, 25000);

setInterval(() => {
  const before = store.tickets.length;
  store.purge();
  if (store.tickets.length !== before) broadcast();
}, 60000);

function localIps() {
  const out = [];
  for (const [name, addrs] of Object.entries(os.networkInterfaces())) {
    for (const a of addrs || []) {
      if (a.family === 'IPv4' && !a.internal) out.push({ iface: name, address: a.address, netmask: a.netmask });
    }
  }
  return out;
}

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.ico': 'image/x-icon',
  '.json': 'application/json; charset=utf-8',
  '.webmanifest': 'application/manifest+json',
};

function sendJson(res, code, body) {
  res.writeHead(code, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' });
  res.end(JSON.stringify(body));
}

function readBody(req) {
  return new Promise((resolve) => {
    let data = '';
    req.on('data', (c) => {
      data += c;
      if (data.length > 1e6) req.destroy();
    });
    req.on('end', () => {
      try {
        resolve(data ? JSON.parse(data) : {});
      } catch {
        resolve({});
      }
    });
  });
}

function serveStatic(req, res) {
  let rel = decodeURIComponent(new URL(req.url, 'http://x').pathname);
  if (rel === '/' || rel === '/settings') rel = '/index.html';
  const file = path.normalize(path.join(PUBLIC, rel));
  if (!file.startsWith(PUBLIC)) {
    res.writeHead(403);
    return res.end();
  }
  fs.readFile(file, (err, buf) => {
    if (err) {
      res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
      return res.end('Ikke fundet');
    }
    res.writeHead(200, { 'Content-Type': MIME[path.extname(file)] || 'application/octet-stream', 'Cache-Control': 'no-cache' });
    res.end(buf);
  });
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, 'http://x');
  const p = url.pathname;

  if (p === '/api/events' && req.method === 'GET') {
    res.writeHead(200, {
      'Content-Type': 'text/event-stream; charset=utf-8',
      'Cache-Control': 'no-store',
      Connection: 'keep-alive',
      'X-Accel-Buffering': 'no',
    });
    res.write('retry: 2000\n');
    res.write('event: state\ndata: ' + JSON.stringify(state()) + '\n\n');
    clients.add(res);
    req.on('close', () => clients.delete(res));
    return;
  }

  if (p === '/api/state' && req.method === 'GET') return sendJson(res, 200, state());

  const m = p.match(/^\/api\/tickets\/([^/]+)\/(done|restore)$/);
  if (m && req.method === 'POST') {
    const t = store.setStatus(decodeURIComponent(m[1]), m[2] === 'done' ? 'done' : 'active');
    return t ? sendJson(res, 200, t) : sendJson(res, 404, { error: 'Bonnen findes ikke' });
  }

  const pm = p.match(/^\/api\/tickets\/([^/]+)\/print$/);
  if (pm && req.method === 'POST') {
    const t = store.tickets.find((x) => x.id === decodeURIComponent(pm[1]));
    if (!t) return sendJson(res, 404, { error: 'Bonnen findes ikke' });
    const r = await printBytes(print.ticketBytes(t.lines || [], { copy: 'KOPI ' + hhmmNow() }), 'Bon ' + (t.orderNo || t.seq));
    return sendJson(res, r.ok ? 200 : 502, r);
  }

  if (p === '/api/printer/test' && req.method === 'POST') {
    const r = await printBytes(print.testPageBytes(store.settings.printerName), 'Testudskrift');
    return sendJson(res, r.ok ? 200 : 502, r);
  }

  if (p === '/api/tickets' && req.method === 'DELETE') {
    store.clearAll();
    return sendJson(res, 200, { ok: true });
  }

  if (p === '/api/test' && req.method === 'POST') {
    const added = printer.ingest(nextSample(), 'test');
    return sendJson(res, 200, { added: added.length });
  }

  const lm = p.match(/^\/api\/logo\/(dark|light)$/);
  if (lm) {
    const mode = lm[1];
    if (req.method === 'GET') {
      const l = logoFile(mode);
      if (!l) return sendJson(res, 404, { error: 'Intet logo' });
      res.writeHead(200, { 'Content-Type': l.type, 'Cache-Control': 'no-cache', 'X-Content-Type-Options': 'nosniff' });
      return fs.createReadStream(l.file).pipe(res);
    }
    if (req.method === 'PUT') {
      let buf;
      try {
        buf = await readRaw(req, 2 * 1024 * 1024);
      } catch {
        return sendJson(res, 413, { error: 'Billedet er for stort. Højst 2 MB.' });
      }
      const kind = imageKind(buf);
      if (!kind) return sendJson(res, 415, { error: 'Vælg en PNG, JPG, WebP eller GIF.' });
      removeLogo(mode);
      fs.writeFileSync(path.join(DATA, `logo-${mode}.${kind}`), buf);
      logoVersion = Date.now();
      broadcast();
      return sendJson(res, 200, logoInfo());
    }
    if (req.method === 'DELETE') {
      removeLogo(mode);
      logoVersion = Date.now();
      broadcast();
      return sendJson(res, 200, logoInfo());
    }
  }

  if (p === '/api/settings' && req.method === 'GET') return sendJson(res, 200, store.settings);
  if (p === '/api/settings' && req.method === 'PUT') {
    const body = await readBody(req);
    const webPortBefore = store.settings.webPort;
    const next = store.updateSettings(body);
    return sendJson(res, 200, { settings: next, restartNeeded: next.webPort !== webPortBefore });
  }

  if (p.startsWith('/api/')) return sendJson(res, 404, { error: 'Ukendt adresse' });
  if (req.method !== 'GET' && req.method !== 'HEAD') {
    res.writeHead(405);
    return res.end();
  }
  serveStatic(req, res);
});

server.listen(store.settings.webPort, () => {
  const ips = localIps().map((i) => i.address);
  console.log(`[web] skærmen kører på http://localhost:${store.settings.webPort}` + (ips.length ? ` (også http://${ips[0]}:${store.settings.webPort})` : ''));
});

function shutdown() {
  store.flush();
  process.exit(0);
}
process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
