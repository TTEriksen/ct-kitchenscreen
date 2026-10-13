'use strict';

// Sample print jobs in ESC/POS, encoded in PC865 the way a Nordic till sends them.
// Used by the "Modtag testbon" button and by tools/send-test.js.

const CP865 = {
  'Ç': 0x80, 'ü': 0x81, 'é': 0x82, 'â': 0x83, 'ä': 0x84, 'à': 0x85, 'å': 0x86, 'ç': 0x87,
  'ê': 0x88, 'ë': 0x89, 'è': 0x8a, 'Ä': 0x8e, 'Å': 0x8f, 'É': 0x90, 'æ': 0x91, 'Æ': 0x92,
  'ô': 0x93, 'ö': 0x94, 'ò': 0x95, 'û': 0x96, 'ù': 0x97, 'Ö': 0x99, 'Ü': 0x9a, 'ø': 0x9b, 'Ø': 0x9d, '·': 0xfa, '×': 0x78,
};

function enc(text) {
  const out = [];
  for (const ch of text) {
    if (ch.charCodeAt(0) < 0x80) out.push(ch.charCodeAt(0));
    else out.push(CP865[ch] || 0x3f);
  }
  return out;
}

const ESC = 0x1b;
const GS = 0x1d;
const init = [ESC, 0x40, ESC, 0x74, 5];
const big = (on) => [GS, 0x21, on ? 0x11 : 0x00];
const bold = (on) => [ESC, 0x45, on ? 1 : 0];
const red = (on) => [ESC, 0x72, on ? 1 : 0];
const inv = (on) => [GS, 0x42, on ? 1 : 0];
const center = (on) => [ESC, 0x61, on ? 1 : 0];
const cut = [ESC, 0x64, 4, GS, 0x56, 0x01];
const line = (t) => [...enc(t), 0x0a];
const rule = line('-'.repeat(32));

function now(offsetMin = 0) {
  const d = new Date(Date.now() + offsetMin * 60000);
  return String(d.getHours()).padStart(2, '0') + ':' + String(d.getMinutes()).padStart(2, '0');
}
function today() {
  const d = new Date();
  return String(d.getDate()).padStart(2, '0') + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + d.getFullYear();
}

let counter = 1040;

const SAMPLES = [
  () => [
    ...init, ...center(true), ...big(true), ...line('KØKKEN'), ...big(false), ...center(false),
    ...line('Bon nr: ' + ++counter),
    ...big(true), ...line('Bord 12'), ...big(false),
    ...line('4 pers.'),
    ...line('Tjener: Mette'),
    ...line(today() + ' ' + now()),
    ...rule,
    ...bold(true), ...line('HOVEDRET'), ...bold(false),
    ...big(true), ...line('2 x Wienerschnitzel'), ...big(false),
    ...line('   - 1 uden kapers'),
    ...line('   - Ekstra smørsauce'),
    ...big(true), ...line('1 x Stjerneskud'), ...big(false),
    ...red(true), ...line('   - ALLERGI: Gluten, glutenfrit brød'), ...red(false),
    ...big(true), ...line('1 x Børnefrikadeller'), ...big(false),
    ...line('   - Kun kartofler, ingen sovs'),
    ...rule,
    ...line('Note: Børneretten først, gerne hurtigt'),
    ...cut,
  ],
  () => [
    ...init,
    ...line('Ordre: ' + ++counter + '        ' + now()),
    ...big(true), ...line('BORD 21'), ...big(false),
    ...line('Gæster: 6      Tjener: Sofie'),
    ...rule,
    ...bold(true), ...line('FORRET'), ...bold(false),
    ...line('6 Dagens suppe'),
    ...line('    Plads 3 uden pesto - nøddeallergi'),
    ...line('6 Hjemmebagt brød'),
    ...bold(true), ...line('HOVEDRET'), ...bold(false),
    ...line('4 Rib-eye 250 g'),
    ...line('    2 rød'),
    ...line('    2 medium'),
    ...line('2 Laks'),
    ...line('    Ingen dild'),
    ...rule,
    ...inv(true), ...line('*** SELSKAB - SERVER SAMLET ***'), ...inv(false),
    ...cut,
  ],
  () => [
    ...init, ...center(true), ...big(true), ...line('TAKE AWAY'), ...big(false), ...center(false),
    ...line('Ordre #' + ++counter),
    ...line('Kl. ' + now()),
    ...line('Navn: Hansen'),
    ...line('Afhentes ' + now(25)),
    ...rule,
    ...line('3 x Burger'),
    ...line('    uden løg'),
    ...line('3 x Pommes frites'),
    ...line('1 x Ekstra aioli'),
    ...cut,
  ],
  () => [
    ...init, ...big(true), ...line('BESKED'), ...big(false),
    ...line('Fra: Jonas  ' + now()),
    ...rule,
    ...line('Bord 12: hold hovedretten 10 min.'),
    ...line('Gæsterne venter på to mere.'),
    ...cut,
  ],
  () => [
    ...init,
    ...line('Bon ' + ++counter),
    ...big(true), ...line('Bord 9'), ...big(false),
    ...line('2 personer  ' + now()),
    ...line('Tjener: Sofie'),
    ...rule,
    ...bold(true), ...line('DESSERT'), ...bold(false),
    ...line('2 x Crème brûlée'),
    ...line('1 x Vaniljeis'),
    ...red(true), ...line('    LAKTOSEFRI'), ...red(false),
    ...cut,
  ],
];

let next = 0;
function nextSample() {
  const buf = Buffer.from(SAMPLES[next % SAMPLES.length]());
  next++;
  return buf;
}

module.exports = { nextSample, SAMPLES };
