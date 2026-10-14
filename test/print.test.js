'use strict';

const test = require('node:test');
const assert = require('node:assert');
const net = require('net');
const { decode } = require('../server/escpos');
const { SAMPLES } = require('../server/samples');
const print = require('../server/print');

test('a printed ticket decodes back to the same lines and styles', () => {
  const [page] = decode(Buffer.from(SAMPLES[0]()));
  const [again] = decode(print.ticketBytes(page.lines));
  assert.deepStrictEqual(again.lines.map((l) => l.text), page.lines.map((l) => l.text));
  const red = again.lines.find((l) => l.text.includes('ALLERGI'));
  assert.ok(red.red, 'allergen line stays red');
  assert.ok(again.lines.find((l) => l.text === 'KØKKEN').big, 'heading stays large');
});

test('a reprint starts with the copy heading', () => {
  const [page] = decode(Buffer.from(SAMPLES[2]()));
  const [again] = decode(print.ticketBytes(page.lines, { copy: 'KOPI 18:42' }));
  assert.strictEqual(again.lines[0].text, 'KOPI 18:42');
  assert.ok(again.lines[0].inverse);
});

test('sends the bytes to a network printer', async () => {
  const received = [];
  const server = net.createServer((s) => s.on('data', (d) => received.push(d)));
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  const { port } = server.address();
  await print.send('127.0.0.1', port, print.testPageBytes('Test'));
  await new Promise((r) => setTimeout(r, 50));
  server.close();
  const [page] = decode(Buffer.concat(received));
  assert.strictEqual(page.lines[0].text, 'TESTUDSKRIFT');
  assert.ok(page.lines.some((l) => l.text === 'Æ Ø Å æ ø å é'));
});

test('reports a printer that is not there', async () => {
  const server = net.createServer();
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  const { port } = server.address();
  await new Promise((r) => server.close(r));
  await assert.rejects(print.send('127.0.0.1', port, Buffer.from('x')), /afviser forbindelsen/);
});
