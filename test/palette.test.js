'use strict';

const test = require('node:test');
const assert = require('node:assert');
const PAL = require('../public/palette.js');

const readable = (seed) => {
  for (const dark of [true, false]) {
    const p = PAL.compute(seed, dark);
    for (const c of p.checks) assert.ok(c.ratio >= 4.5, `${seed.name} ${dark ? 'mørk' : 'lys'}: ${c.label} ${c.ratio.toFixed(2)}`);
    assert.ok(PAL.contrast(p.onBad, p.bad) >= 4.5, `${seed.name}: late chip`);
    assert.ok(PAL.contrast(p.ok, p.card) >= 4.5 && PAL.contrast(p.warn, p.card) >= 4.5, `${seed.name}: status colours`);
    assert.ok(!PAL.isRedLike(p.primary), `${seed.name}: modifiers look like allergens`);
  }
};

test('all five palettes are readable in dark and light mode', () => {
  assert.strictEqual(PAL.PRESETS.length, 5);
  PAL.PRESETS.forEach(readable);
});

test('extreme custom colours are adjusted until readable', () => {
  for (const accent of ['#FFFF00', '#FFFFFF', '#000000', '#0A1A3A', '#7FFFD4', '#ED1C24']) {
    for (const neutralTint of [0, 0.2, 0.4]) {
      for (const neutralHue of [0, 60, 210, 300]) readable({ name: `${accent} ${neutralHue}/${neutralTint}`, accent, neutralHue, neutralTint });
    }
  }
});
