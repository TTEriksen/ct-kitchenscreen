#!/usr/bin/env node
'use strict';

// Sends print jobs to the kitchen screen the way a till would: raw bytes over TCP.
//
//   node tools/send-test.js                       → one sample ticket to 127.0.0.1:9100
//   node tools/send-test.js 192.168.1.50 9100 5   → five sample tickets to that screen
//   node tools/send-test.js 192.168.1.50 9100 --file job.bin
//                                                 → a captured print job, byte for byte

const net = require('net');
const fs = require('fs');
const { nextSample } = require('../server/samples');

const args = process.argv.slice(2);
const fileIdx = args.indexOf('--file');
const file = fileIdx >= 0 ? args.splice(fileIdx, 2)[1] : null;
const host = args[0] || '127.0.0.1';
const port = Number(args[1] || 9100);
const count = file ? 1 : Math.max(1, Number(args[2] || 1));

function send(buf) {
  return new Promise((resolve, reject) => {
    const sock = net.connect(port, host, () => {
      sock.end(buf);
    });
    sock.on('close', resolve);
    sock.on('error', reject);
  });
}

(async () => {
  for (let i = 0; i < count; i++) {
    const buf = file ? fs.readFileSync(file) : nextSample();
    await send(buf);
    console.log(`Sendt ${buf.length} bytes til ${host}:${port}`);
    await new Promise((r) => setTimeout(r, 300));
  }
})().catch((err) => {
  console.error('Kunne ikke sende: ' + err.message);
  process.exit(1);
});
