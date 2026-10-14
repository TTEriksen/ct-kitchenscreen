'use strict';

// Printing a ticket on a real network printer (ESC/POS over TCP, port 9100).
// The ticket is rebuilt from its stored lines, keeping bold, large, red,
// reversed and alignment, encoded in PC865 so æ, ø and å come out right.

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

const ESC = 0x1b;
const GS = 0x1d;

/**
 * ESC/POS bytes for one ticket.
 * @param {{text:string,bold?:boolean,big?:boolean,red?:boolean,inverse?:boolean,align?:string}[]} lines
 * @param {{ copy?: string }} opts  copy: a heading such as "KOPI 18:42" for reprints
 */
function ticketBytes(lines, opts = {}) {
  const b = [ESC, 0x40, ESC, 0x74, 5];
  const line = (l) => {
    b.push(ESC, 0x61, l.align === 'center' ? 1 : l.align === 'right' ? 2 : 0);
    b.push(ESC, 0x45, l.bold || l.big ? 1 : 0);
    b.push(GS, 0x21, l.big ? 0x11 : 0x00);
    b.push(ESC, 0x72, l.red ? 1 : 0);
    b.push(GS, 0x42, l.inverse ? 1 : 0);
    b.push(...encode(l.text || ''), 0x0a);
  };
  if (opts.copy) {
    line({ text: opts.copy, bold: true, align: 'center', inverse: true });
    line({ text: '' });
  }
  for (const l of lines) line(l);
  b.push(ESC, 0x40, ESC, 0x64, 4, GS, 0x56, 0x42, 0x00); // reset, feed, partial cut
  return Buffer.from(b);
}

function testPageBytes(name) {
  const now = new Date();
  const t = String(now.getHours()).padStart(2, '0') + ':' + String(now.getMinutes()).padStart(2, '0');
  return ticketBytes([
    { text: 'TESTUDSKRIFT', big: true, align: 'center' },
    { text: name || 'Køkkenskærm', align: 'center' },
    { text: '' },
    { text: 'Printeren er forbundet.' },
    { text: 'Æ Ø Å æ ø å é' },
    { text: 'Fed tekst', bold: true },
    { text: 'Rød tekst (2-farve printer)', red: true },
    { text: 'Kl. ' + t },
  ]);
}

/** Sends bytes to host:port. Resolves when the printer has the data, rejects with a Danish message. */
function send(host, port, bytes, timeoutMs = 5000) {
  return new Promise((resolve, reject) => {
    const sock = net.connect({ host, port });
    const fail = (msg) => {
      sock.destroy();
      reject(new Error(msg));
    };
    sock.setTimeout(timeoutMs, () => fail(`Printeren ${host}:${port} svarer ikke`));
    sock.on('error', (err) => {
      if (err.code === 'ECONNREFUSED') fail(`Printeren ${host}:${port} afviser forbindelsen`);
      else if (err.code === 'EHOSTUNREACH' || err.code === 'ENETUNREACH') fail(`Printeren ${host} kan ikke nås på netværket`);
      else fail(`Kunne ikke printe: ${err.message}`);
    });
    sock.on('connect', () => sock.end(bytes));
    sock.on('close', (hadError) => {
      if (!hadError) resolve();
    });
  });
}

module.exports = { ticketBytes, testPageBytes, send, encode };
