'use strict';

const http = require('http');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { Store } = require('./store');
const { PrinterEmulator } = require('./printer');
const { nextSample } = require('./samples');

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
  return { active, done, settings: store.settings, status: { ...printer.status, ips: localIps() }, serverTime: new Date().toISOString() };
}

let broadcastTimer = null;
function broadcast() {
  clearTimeout(broadcastTimer);
  broadcastTimer = setTimeout(() => {
    const msg = 'event: state\ndata: ' + JSON.stringify(state()) + '\n\n';
    for (const res of clients) res.write(msg);
  }, 30);
}

store.onChange((kind, payload) => {
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

  if (p === '/api/tickets' && req.method === 'DELETE') {
    store.clearAll();
    return sendJson(res, 200, { ok: true });
  }

  if (p === '/api/test' && req.method === 'POST') {
    const added = printer.ingest(nextSample(), 'test');
    return sendJson(res, 200, { added: added.length });
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
