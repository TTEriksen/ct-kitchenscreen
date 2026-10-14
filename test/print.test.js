'use strict';

const test = require('node:test');
const assert = require('node:assert');
const net = require('net');
const { decode } = require('../server/escpos');
const { SAMPLES } = require('../server/samples');
const print = require('../server/print');

const P48 = { paper: '80 mm', cols: 48, dots: 576 };
const P32 = { paper: '58 mm', cols: 32, dots: 384 };

test('no printed line is wider than the paper, at any width', () => {
  for (const cols of [32, 42, 48]) {
    for (const make of SAMPLES) {
      const [page] = decode(Buffer.from(make()));
      const [printed] = decode(print.ticketBytes(page.lines, { profile: { cols, dots: 0 }, copy: 'KOPI 18:42' }));
      for (const l of printed.lines) {
        const width = l.big ? Math.floor(cols / 2) : cols;
        assert.ok(l.text.length <= width, `${cols} cols: "${l.text}" is ${l.text.length} wide (max ${width})`);
      }
    }
  }
});

test('separators fill the width and left/right lines reach both edges', () => {
  const out = print.layoutLines([
    { text: '-'.repeat(32) },
    { text: 'Ordre: 1042        18:05' },
    { text: '1 Burger           145,00' },
  ], 48);
  assert.strictEqual(out[0].text, '-'.repeat(48));
  assert.strictEqual(out[1].text.length, 48);
  assert.ok(out[1].text.startsWith('Ordre: 1042') && out[1].text.endsWith('18:05'));
  assert.ok(out[2].text.endsWith('145,00') && out[2].text.length === 48);
});

test('long lines wrap at words with the continuation under the dish name', () => {
  const out = print.layoutLines([{ text: '2 x Pariserbøf med alt tilbehør, rødbeder, peberrod og kapers' }], 32);
  assert.ok(out.length > 1);
  assert.ok(out.every((l) => l.text.length <= 32));
  assert.ok(out[1].text.startsWith('    ') && !out[1].text.startsWith('     '), 'hangs under the name');
  assert.ok(!out.some((l) => /\S-\S/.test(l.text.slice(-1))), 'cuts at spaces');
});

test('double-size lines count as twice as wide', () => {
  const out = print.layoutLines([{ text: 'Bord 12 · Terrassen ved vinduet', big: true }], 32);
  assert.ok(out.every((l) => l.text.length <= 16));
});

test('the job takes the whole print area', () => {
  const bytes = print.ticketBytes([{ text: 'x' }], { profile: P48 });
  const i = bytes.indexOf(Buffer.from([0x1d, 0x57]));
  assert.ok(i > 0, 'sets the print area width (GS W)');
  assert.strictEqual(bytes[i + 2] + bytes[i + 3] * 256, 576);
  assert.ok(bytes.indexOf(Buffer.from([0x1d, 0x4c, 0, 0])) > 0, 'left margin 0 (GS L)');
});

test('known models give their width', () => {
  assert.strictEqual(print.profileForModel('TM-T88V').cols, 42);
  assert.strictEqual(print.profileForModel('TM-T20III').cols, 48);
  assert.strictEqual(print.profileForModel('TM-m30II').cols, 48);
  assert.strictEqual(print.profileForModel('TM-m10').cols, 32);
  assert.strictEqual(print.profileForModel('Mystery 3000'), null);
  assert.strictEqual(print.chooseProfile('58-32', { model: 'TM-T88V' }).cols, 32, 'the setting wins');
  assert.strictEqual(print.chooseProfile('auto', {}).source, 'fallback');
});

/** A pretend Epson printer that answers status and ID queries. */
async function fakePrinter({ model = 'TM-T88V', paperOut = false, answers = true } = {}) {
  const jobs = [];
  const server = net.createServer((s) => {
    const chunks = [];
    s.on('data', (d) => {
      chunks.push(d);
      if (!answers) return;
      for (let i = 0; i < d.length - 2; i++) {
        if (d[i] === 0x10 && d[i + 1] === 0x04) s.write(Buffer.from([d[i + 2] === 4 && paperOut ? 0x72 : 0x12]));
        if (d[i] === 0x1d && d[i + 1] === 0x49 && d[i + 2] === 0x42) s.write(Buffer.concat([Buffer.from([0x5f]), Buffer.from('EPSON'), Buffer.from([0])]));
        if (d[i] === 0x1d && d[i + 1] === 0x49 && d[i + 2] === 0x43) s.write(Buffer.concat([Buffer.from([0x5f]), Buffer.from(model), Buffer.from([0])]));
      }
    });
    s.on('end', () => jobs.push(Buffer.concat(chunks)));
  });
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  return { port: server.address().port, jobs, close: () => new Promise((r) => server.close(r)) };
}

const build = (profile, info) => print.ticketBytes(print.testPageLines('Test', profile, info), { profile });

test('asks the printer its model and prints at its width', async () => {
  const p = await fakePrinter({ model: 'TM-T20III' });
  const { profile, info } = await print.printJob('127.0.0.1', p.port, 'auto', build);
  await new Promise((r) => setTimeout(r, 50));
  await p.close();
  assert.strictEqual(info.model, 'TM-T20III');
  assert.strictEqual(info.maker, 'EPSON');
  assert.deepStrictEqual([profile.cols, profile.source], [48, 'printer']);
  const [page] = decode(p.jobs[0]);
  assert.ok(page.lines.some((l) => l.text === '123456789012345678901234567890123456789012345678'), 'ruler is 48 wide');
});

test('stops before printing when the printer is out of paper', async () => {
  const p = await fakePrinter({ paperOut: true });
  await assert.rejects(print.printJob('127.0.0.1', p.port, 'auto', build), /mangler papir/);
  await p.close();
});

test('a printer that does not answer gets the safe width', async () => {
  const p = await fakePrinter({ answers: false });
  const { profile } = await print.printJob('127.0.0.1', p.port, 'auto', build);
  await new Promise((r) => setTimeout(r, 50));
  await p.close();
  assert.deepStrictEqual([profile.cols, profile.source], [42, 'fallback']);
  assert.ok(decode(p.jobs[0])[0].lines.some((l) => l.text === 'TESTUDSKRIFT'));
});

test('reports a printer that is not there', async () => {
  const server = net.createServer();
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  const { port } = server.address();
  await new Promise((r) => server.close(r));
  await assert.rejects(print.printJob('127.0.0.1', port, 'auto', build), /afviser forbindelsen/);
});

test('a reprint starts with the copy heading', () => {
  const [page] = decode(Buffer.from(SAMPLES[2]()));
  const [again] = decode(print.ticketBytes(page.lines, { copy: 'KOPI 18:42', profile: P32 }));
  assert.strictEqual(again.lines[0].text, 'KOPI 18:42');
  assert.ok(again.lines[0].inverse);
});
