'use strict';

// Printing a ticket on a real network printer (ESC/POS over TCP, port 9100).
//
// Before printing, the printer is asked about itself on the same connection:
// paper and cover status (DLE EOT) and maker and model (GS I). The model gives
// the paper width; the ticket is then laid out again for exactly that many
// characters per line, so it uses the whole width and no line runs over.
// Text is encoded in PC865 so æ, ø and å come out right.

const net = require('net');

const CP865 = {
  'Ç': 0x80, 'ü': 0x81, 'é': 0x82, 'â': 0x83, 'ä': 0x84, 'à': 0x85, 'å': 0x86, 'ç': 0x87,
  'ê': 0x88, 'ë': 0x89, 'è': 0x8a, 'ï': 0x8b, 'î': 0x8c, 'ì': 0x8d, 'Ä': 0x8e, 'Å': 0x8f,
  'É': 0x90, 'æ': 0x91, 'Æ': 0x92, 'ô': 0x93, 'ö': 0x94, 'ò': 0x95, 'û': 0x96, 'ù': 0x97,
  'ÿ': 0x98, 'Ö': 0x99, 'Ü': 0x9a, 'ø': 0x9b, '£': 0x9c, 'Ø': 0x9d, 'á': 0xa0, 'í': 0xa1,
  'ó': 0xa2, 'ú': 0xa3, 'ñ': 0xa4, 'Ñ': 0xa5, '¤': 0xaf, '½': 0xab, '¼': 0xac, '°': 0xf8,
  '·': 0xfa, '×': 0x78, '–': 0x2d, '—': 0x2d, '‘': 0x27, '’': 0x27, '“': 0x22, '”': 0x22, '…': 0x2e,
};

function encode(text) {
  const out = [];
  for (const ch of text) {
    const c = ch.codePointAt(0);
    if (c < 0x80) out.push(c);
    else out.push(CP865[ch] !== undefined ? CP865[ch] : 0x3f);
  }
  return out;
}

// ---------- Paper width ----------

/** Paper widths a user can pick in settings. dots = printable width, cols = Font A characters per line. */
const PAPERS = {
  '80-48': { paper: '80 mm', cols: 48, dots: 576 },
  '80-42': { paper: '80 mm', cols: 42, dots: 512 },
  '58-32': { paper: '58 mm', cols: 32, dots: 384 },
};

/** Used when the printer does not say what it is: fits every 80 mm printer. */
const FALLBACK = { paper: '80 mm', cols: 42, dots: 512 };

// Known models → width. The first matching pattern wins.
const MODELS = [
  [/TM-?T88/i, PAPERS['80-42']],
  [/TM-?(m10|P20|P60|T20.*58|L90.*58)/i, PAPERS['58-32']],
  [/TM-?U2\d\d/i, { paper: '76 mm', cols: 40, dots: 0 }], // impact printers: no dot area
  [/TM-?(T20|T70|T81|T82|T83|T90|T100|m30|m50|L90|H6000)/i, PAPERS['80-48']],
  [/(TSP1\d\d|TSP6\d\d|TSP7\d\d|mC-Print3|TSP143)/i, PAPERS['80-48']],
  [/(mC-Print2|SM-[LST]2|TSP6.*58)/i, PAPERS['58-32']],
  [/(SRP-?3\d\d|SRP-?Q3|RP-?F10|RP-?33)/i, PAPERS['80-48']],
];

function profileForModel(model) {
  if (!model) return null;
  for (const [re, p] of MODELS) if (re.test(model)) return p;
  return null;
}

/**
 * The width to print with: the user's choice, else what the printer told us, else the safe fallback.
 * @returns {{paper:string, cols:number, dots:number, source:'setting'|'printer'|'fallback'}}
 */
function chooseProfile(setting, info) {
  if (setting && PAPERS[setting]) return { ...PAPERS[setting], source: 'setting' };
  const fromModel = info && profileForModel(info.model);
  if (fromModel) return { ...fromModel, source: 'printer' };
  return { ...FALLBACK, source: 'fallback' };
}

// ---------- Laying the ticket out for the printer's width ----------

const RULE = /^[\s\-=_*~.#+]+$/;

/** Splits text into pieces of at most `width` characters, at spaces where possible. */
function wrapWords(text, width) {
  const out = [];
  let rest = text;
  while (rest.length > width) {
    let cut = rest.lastIndexOf(' ', width);
    if (cut < width * 0.4) cut = width; // no good space: cut the word
    out.push(rest.slice(0, cut).replace(/\s+$/, ''));
    rest = rest.slice(cut).replace(/^\s+/, '');
  }
  if (rest.length || !out.length) out.push(rest);
  return out;
}

/**
 * Lays printed lines out again for a printer with `cols` characters per line:
 * rules fill the width, "left … right" lines are spread to both edges, long
 * lines wrap with a hanging indent, and double-size lines count double.
 */
function layoutLines(lines, cols) {
  const out = [];
  for (const l of lines) {
    const text = String(l.text || '').replace(/\s+$/, '');
    const width = Math.max(8, l.big ? Math.floor(cols / 2) : cols);
    const keep = (t) => out.push({ ...l, text: t });

    if (!text.trim()) { keep(''); continue; }

    // Separator lines: redraw across the whole width.
    if (RULE.test(text) && text.trim().length >= 6) {
      const ch = text.trim()[0];
      keep(ch.repeat(width));
      continue;
    }

    // "Left      right" (two parts with a wide gap): left edge and right edge.
    const two = l.align !== 'center' && text.match(/^(\s*\S(?:.*?\S)?)\s{3,}(\S(?:.*\S)?)$/);
    if (two && two[2].length <= Math.floor(width / 2)) {
      const left = two[1];
      const right = two[2];
      if (left.length + 1 + right.length <= width) {
        keep(left + ' '.repeat(width - left.length - right.length) + right);
      } else {
        for (const w of wrapWords(left, width)) keep(w);
        keep(' '.repeat(width - right.length) + right);
      }
      continue;
    }

    if (text.length <= width) { keep(text); continue; }

    // Too long: wrap, indenting the continuation under the dish name or the line's own indent.
    const lead = text.match(/^\s*/)[0].length;
    const item = text.match(/^(\s*\d{1,3}\s*(?:x|×|stk\.?)?\s+)/i);
    const hang = Math.min(Math.floor(width / 2), item ? item[1].length : lead);
    const words = wrapWords(text.trim(), width - lead);
    keep(' '.repeat(lead) + words[0]);
    const tail = words.slice(1).join(' ');
    for (const w of tail ? wrapWords(tail, width - hang) : []) keep(' '.repeat(hang) + w);
  }
  return out;
}

// ---------- ESC/POS ----------

const ESC = 0x1b;
const GS = 0x1d;
const DLE = 0x10;

/**
 * ESC/POS bytes for one ticket, laid out for `profile`.
 * @param {{text:string,bold?:boolean,big?:boolean,red?:boolean,inverse?:boolean,align?:string}[]} lines
 * @param {{ copy?: string, profile?: {cols:number, dots:number} }} opts
 */
function ticketBytes(lines, opts = {}) {
  const profile = opts.profile || FALLBACK;
  const b = [ESC, 0x40, ESC, 0x74, 5];
  // Use the whole paper: no left margin, print area = the printer's full width.
  if (profile.dots) b.push(GS, 0x4c, 0, 0, GS, 0x57, profile.dots & 255, profile.dots >> 8);
  const all = opts.copy ? [{ text: opts.copy, bold: true, align: 'center', inverse: true }, { text: '' }, ...lines] : lines;
  for (const l of layoutLines(all, profile.cols)) {
    b.push(ESC, 0x61, l.align === 'center' ? 1 : l.align === 'right' ? 2 : 0);
    b.push(ESC, 0x45, l.bold || l.big ? 1 : 0);
    b.push(GS, 0x21, l.big ? 0x11 : 0x00);
    b.push(ESC, 0x72, l.red ? 1 : 0);
    b.push(GS, 0x42, l.inverse ? 1 : 0);
    b.push(...encode(l.text || ''), 0x0a);
  }
  b.push(ESC, 0x40, ESC, 0x64, 4, GS, 0x56, 0x42, 0x00); // reset, feed, partial cut
  return Buffer.from(b);
}

function testPageLines(name, profile, info) {
  const now = new Date();
  const t = String(now.getHours()).padStart(2, '0') + ':' + String(now.getMinutes()).padStart(2, '0');
  const ruler = '1234567890'.repeat(Math.ceil(profile.cols / 10)).slice(0, profile.cols);
  return [
    { text: 'TESTUDSKRIFT', big: true, align: 'center' },
    { text: name || 'Køkkenskærm', align: 'center' },
    { text: '-'.repeat(10) },
    { text: 'Printer:   ' + ((info && [info.maker, info.model].filter(Boolean).join(' ')) || 'ukendt model') },
    { text: `Bredde:    ${profile.paper} · ${profile.cols} tegn pr. linje` },
    { text: ruler },
    { text: 'Æ Ø Å æ ø å é' },
    { text: 'Fed tekst', bold: true },
    { text: 'Rød tekst (2-farve printer)', red: true },
    { text: 'Kl.' + ' '.repeat(5) + t },
  ];
}

// ---------- Talking to the printer ----------

const DANISH = {
  refused: (h, p) => `Printeren ${h}:${p} afviser forbindelsen`,
  unreachable: (h) => `Printeren ${h} kan ikke nås på netværket`,
  silent: (h, p) => `Printeren ${h}:${p} svarer ikke`,
  paper: 'Printeren mangler papir',
  cover: 'Printerens låg er åbent',
};

/** One connection to a printer: ask it questions, then send the job. */
function connect(host, port, timeoutMs = 5000) {
  return new Promise((resolve, reject) => {
    const sock = net.connect({ host, port });
    const fail = (msg) => { sock.destroy(); reject(new Error(msg)); };
    sock.setTimeout(timeoutMs, () => fail(DANISH.silent(host, port)));
    sock.once('error', (err) => {
      if (err.code === 'ECONNREFUSED') fail(DANISH.refused(host, port));
      else if (err.code === 'EHOSTUNREACH' || err.code === 'ENETUNREACH') fail(DANISH.unreachable(host));
      else fail(`Kunne ikke printe: ${err.message}`);
    });
    sock.once('connect', () => {
      let buf = Buffer.alloc(0);
      let waiter = null;
      sock.on('data', (d) => {
        buf = Buffer.concat([buf, d]);
        if (waiter) waiter();
      });
      /** Sends a query and waits for a reply matching `done`, or null after `ms`. */
      const ask = (bytes, done, ms = 700) => new Promise((res) => {
        buf = Buffer.alloc(0);
        const finish = (v) => { clearTimeout(timer); waiter = null; res(v); };
        const timer = setTimeout(() => finish(null), ms);
        waiter = () => { const v = done(buf); if (v !== undefined) finish(v); };
        sock.write(Buffer.from(bytes));
      });
      resolve({ sock, ask });
    });
  });
}

const statusByte = (b) => (b.length >= 1 && (b[0] & 0x93) === 0x12 ? b[0] : undefined);
const infoString = (b) => {
  const start = b.indexOf(0x5f);
  if (start < 0) return undefined;
  const end = b.indexOf(0x00, start);
  if (end < 0) return undefined;
  return b.slice(start + 1, end).toString('latin1').trim();
};

/**
 * Asks the printer about itself. Printers that do not answer real-time
 * queries simply return {} after a short wait.
 * @returns {Promise<{responds?:boolean, paperOut?:boolean, coverOpen?:boolean, maker?:string, model?:string}>}
 */
async function probe(ask) {
  const info = {};
  const paper = await ask([DLE, 0x04, 4], statusByte);
  if (paper === null) return info; // no real-time replies: nothing more to learn
  info.responds = true;
  info.paperOut = (paper & 0x60) === 0x60;
  const offline = await ask([DLE, 0x04, 2], statusByte);
  if (offline !== null) info.coverOpen = (offline & 0x04) === 0x04;
  info.maker = (await ask([GS, 0x49, 0x42], infoString)) || undefined;
  info.model = (await ask([GS, 0x49, 0x43], infoString)) || undefined;
  return info;
}

/**
 * Connects, asks the printer what it is, lays the job out for its width and prints it.
 * @param {(profile, info) => Buffer} build  makes the bytes once the width is known
 * @returns {Promise<{profile, info}>}
 */
async function printJob(host, port, paperSetting, build) {
  const { sock, ask } = await connect(host, port);
  try {
    const info = await probe(ask);
    if (info.paperOut) throw new Error(DANISH.paper);
    if (info.coverOpen) throw new Error(DANISH.cover);
    const profile = chooseProfile(paperSetting, info);
    await new Promise((res, rej) => {
      sock.once('error', rej);
      sock.end(build(profile, info), res);
    });
    return { profile, info };
  } finally {
    setTimeout(() => sock.destroy(), 1000);
  }
}

/** Sends ready-made bytes (no questions asked). Kept for simple callers and tests. */
async function send(host, port, bytes) {
  const { sock } = await connect(host, port);
  await new Promise((res, rej) => {
    sock.once('error', rej);
    sock.end(bytes, res);
  });
  setTimeout(() => sock.destroy(), 1000);
}

module.exports = { PAPERS, FALLBACK, chooseProfile, profileForModel, layoutLines, wrapWords, ticketBytes, testPageLines, probe, printJob, send, encode };
