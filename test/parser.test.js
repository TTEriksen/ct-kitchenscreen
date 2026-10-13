'use strict';

const test = require('node:test');
const assert = require('node:assert');
const { decode } = require('../server/escpos');
const { parseTicket } = require('../server/parser');
const { SAMPLES } = require('../server/samples');

const parse = (bytes, opts) => decode(Buffer.from(bytes), opts).map((p) => parseTicket(p.lines));

test('decodes PC865 Danish letters and splits on cuts', () => {
  const job = [...SAMPLES[0](), ...SAMPLES[3]()];
  const pages = decode(Buffer.from(job));
  assert.strictEqual(pages.length, 2);
  assert.ok(pages[0].lines.some((l) => l.text === 'KØKKEN' && l.big && l.align === 'center'));
  assert.ok(pages[0].lines.some((l) => l.text.includes('smørsauce')));
});

test('reads table, guests, waiter, items, modifiers, allergens and notes', () => {
  const [t] = parse(SAMPLES[0]());
  assert.strictEqual(t.table, '12');
  assert.strictEqual(t.guests, 4);
  assert.strictEqual(t.waiter, 'Mette');
  assert.ok(t.orderNo);
  assert.strictEqual(t.sections[0].course, 'Hovedret');
  const items = t.sections[0].items;
  assert.deepStrictEqual(items.map((i) => [i.qty, i.name]), [[2, 'Wienerschnitzel'], [1, 'Stjerneskud'], [1, 'Børnefrikadeller']]);
  assert.deepStrictEqual(items[0].mods.map((m) => m.text), ['1 uden kapers', 'Ekstra smørsauce']);
  assert.strictEqual(items[1].allergy, true);
  assert.ok(t.allergens[0].includes('Gluten'));
  assert.deepStrictEqual(t.notes, ['Børneretten først, gerne hurtigt']);
});

test('keeps several courses apart and turns shouted lines into notes', () => {
  const [t] = parse(SAMPLES[1]());
  assert.strictEqual(t.table, '21');
  assert.strictEqual(t.guests, 6);
  assert.deepStrictEqual(t.sections.map((s) => s.course), ['Forret', 'Hovedret']);
  assert.ok(t.allergens.some((a) => /nødde/.test(a)));
  assert.deepStrictEqual(t.notes, ['SELSKAB - SERVER SAMLET']);
});

test('take away tickets without a table', () => {
  const [t] = parse(SAMPLES[2]());
  assert.strictEqual(t.table, null);
  assert.strictEqual(t.takeaway, 'Take away');
  assert.strictEqual(t.sections[0].items.length, 3);
});

test('a ticket without dishes is a message and keeps all its text', () => {
  const [t] = parse(SAMPLES[3]());
  assert.strictEqual(t.isMessage, true);
  assert.match(t.message, /hold hovedretten 10 min/);
});

test('red printed modifiers count as allergens', () => {
  const [t] = parse(SAMPLES[4]());
  const ice = t.sections[0].items[1];
  assert.strictEqual(ice.name, 'Vaniljeis');
  assert.strictEqual(ice.allergy, true);
  assert.strictEqual(t.sections[0].items[0].name, 'Crème brûlée');
});

test('plain UTF-8 text jobs work too', () => {
  const text = 'Bord 7\n2 pers.\n2 x Rød grød med fløde\n  ekstra fløde\nNote: hurtigt\n';
  const [t] = parse(Buffer.from(text, 'utf8'));
  assert.strictEqual(t.table, '7');
  assert.strictEqual(t.sections[0].items[0].name, 'Rød grød med fløde');
  assert.deepStrictEqual(t.sections[0].items[0].mods.map((m) => m.text), ['ekstra fløde']);
  assert.deepStrictEqual(t.notes, ['hurtigt']);
});

test('prices and totals are left out', () => {
  const text = 'Bord 3\n1 Burger           145,00\n2 Cola  50,00 kr\nTotal 245,00\n';
  const [t] = parse(Buffer.from(text, 'latin1'));
  assert.deepStrictEqual(t.sections[0].items.map((i) => i.name), ['Burger', 'Cola']);
  assert.deepStrictEqual(t.extra, []);
});

test('skips raster images and barcodes without leaking bytes', () => {
  const img = [0x1d, 0x76, 0x30, 0, 2, 0, 2, 0, 0x41, 0x42, 0x43, 0x44];
  const qr = [0x1d, 0x28, 0x6b, 3, 0, 0x31, 0x50, 0x30];
  const job = [...img, ...qr, ...Buffer.from('Bord 4\n1 x Suppe\n'), 0x1d, 0x56, 0x00];
  const pages = decode(Buffer.from(job));
  assert.strictEqual(pages.length, 1);
  assert.strictEqual(pages[0].lines[0].text, 'Bord 4');
});

test('Star Line mode bold, red and cut', () => {
  const job = [0x1b, 0x40, 0x1b, 0x45, ...Buffer.from('Bord 8\n'), 0x1b, 0x46, ...Buffer.from('1 x Laks\n'), 0x1b, 0x34, ...Buffer.from('  uden smør\n'), 0x1b, 0x35, 0x1b, 0x64, 0x02];
  const pages = decode(Buffer.from(job), { protocol: 'star' });
  assert.strictEqual(pages.length, 1);
  const [t] = pages.map((p) => parseTicket(p.lines));
  assert.strictEqual(t.table, '8');
  assert.strictEqual(t.sections[0].items[0].allergy, true);
});
