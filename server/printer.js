'use strict';

const net = require('net');
const { decode, realtimeReplies } = require('./escpos');
const { parseTicket } = require('./parser');

/**
 * A raw network printer (port 9100 / JetDirect). Each connection's bytes are
 * collected until the till closes the connection or goes quiet, then decoded;
 * every paper cut in the job becomes its own ticket.
 */
class PrinterEmulator {
  constructor(store, log = console) {
    this.store = store;
    this.log = log;
    this.server = null;
    this.status = { listening: false, address: null, port: null, error: null, lastJobAt: null, jobs: 0 };
  }

  start() {
    const { bindAddress, port } = this.store.settings;
    const server = net.createServer((sock) => this.handle(sock));
    this.server = server;
    server.on('error', (err) => {
      this.status = { ...this.status, listening: false, error: describe(err, port) };
      this.log.error('[printer] ' + this.status.error);
      this.store.emit('status', this.status);
    });
    server.listen(port, bindAddress, () => {
      this.status = { ...this.status, listening: true, address: bindAddress, port, error: null };
      this.log.log(`[printer] lytter på ${bindAddress}:${port}`);
      this.store.emit('status', this.status);
    });
  }

  restart() {
    const old = this.server;
    this.status = { ...this.status, listening: false };
    if (old) old.close(() => this.start());
    else this.start();
  }

  handle(sock) {
    const from = sock.remoteAddress ? sock.remoteAddress.replace(/^::ffff:/, '') : '';
    let chunks = [];
    let timer = null;
    const flush = () => {
      clearTimeout(timer);
      if (!chunks.length) return;
      const buf = Buffer.concat(chunks);
      chunks = [];
      this.ingest(buf, from);
    };
    sock.setTimeout(5 * 60 * 1000, () => sock.destroy());
    sock.on('data', (chunk) => {
      const reply = realtimeReplies(chunk);
      if (reply) sock.write(reply);
      chunks.push(chunk);
      clearTimeout(timer);
      timer = setTimeout(flush, this.store.settings.idleFlushMs || 800);
    });
    sock.on('end', flush);
    sock.on('close', flush);
    sock.on('error', () => {});
  }

  /** Decode a job and store each page as a ticket. Also used for test tickets. */
  ingest(buf, from = 'test') {
    const s = this.store.settings;
    let pages;
    try {
      pages = decode(buf, { protocol: s.protocol, charset: s.charset });
    } catch (err) {
      this.log.error('[printer] kunne ikke læse bon: ' + err.message);
      return [];
    }
    const added = [];
    for (const page of pages) {
      const parsed = parseTicket(page.lines, { allergenWords: s.allergenWords });
      added.push(this.store.add({ from, lines: page.lines, ...parsed }));
    }
    if (pages.length) {
      this.status = { ...this.status, lastJobAt: new Date().toISOString(), jobs: this.status.jobs + pages.length };
      this.store.emit('status', this.status);
      this.log.log(`[printer] ${pages.length} bon(ner) modtaget fra ${from}`);
    }
    return added;
  }
}

function describe(err, port) {
  if (err.code === 'EADDRINUSE') return `Port ${port} er optaget af et andet program`;
  if (err.code === 'EACCES') return `Ingen adgang til port ${port}`;
  if (err.code === 'EADDRNOTAVAIL') return 'IP-adressen findes ikke på denne enhed';
  return err.message;
}

module.exports = { PrinterEmulator };
