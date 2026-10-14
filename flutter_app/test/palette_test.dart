import 'package:ct_kitchenscreen/src/ui/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  void expectReadable(PaletteSeed seed) {
    for (final dark in [true, false]) {
      final p = Palette.from(seed, dark: dark);
      for (final c in p.checks) {
        expect(c.ratio, greaterThanOrEqualTo(c.need), reason: '${seed.name} ${dark ? 'mørk' : 'lys'}: ${c.label} ${c.ratio.toStringAsFixed(2)}');
      }
      expect(contrast(p.strong, p.paperBar), greaterThanOrEqualTo(7), reason: '${seed.name} top bar text');
      expect(contrast(p.onBad, p.bad), greaterThanOrEqualTo(4.5), reason: '${seed.name} late chip');
      expect(contrast(p.ok, p.card), greaterThanOrEqualTo(4.5), reason: '${seed.name} ok');
      expect(contrast(p.warn, p.card), greaterThanOrEqualTo(4.5), reason: '${seed.name} warn');
    }
  }

  test('all five palettes are readable in dark and light mode', () {
    expect(PaletteSeed.presets.length, 5);
    PaletteSeed.presets.forEach(expectReadable);
  });

  test('custom colours are adjusted until readable, even extreme ones', () {
    for (final accent in [
      const Color(0xFFFFFF00), // pale yellow
      const Color(0xFFFFFFFF), // white
      const Color(0xFF000000), // black
      const Color(0xFF0A1A3A), // dark navy
      const Color(0xFF7FFFD4), // light aquamarine
      const Color(0xFFED1C24), // CT red
    ]) {
      for (final tint in [0.0, .2, .4]) {
        for (final hue in [0.0, 60.0, 210.0, 300.0]) {
          expectReadable(PaletteSeed(id: 'custom', name: 'Egen ${hexOf(accent)} $hue/$tint', description: '', accent: accent, neutralHue: hue, neutralTint: tint));
        }
      }
    }
  });

  test('the CTpos palette keeps the brand red for buttons', () {
    final p = Palette.from(PaletteSeed.presets.first, dark: true);
    expect(p.onAccent, const Color(0xFFFFFFFF));
    // #ED1C24 with white text is 4.0:1, so the fill is darkened just enough, close to CT red 600.
    final hsl = HSLColor.fromColor(p.accent);
    expect(hsl.hue, closeTo(HSLColor.fromColor(const Color(0xFFED1C24)).hue, 1));
    expect(contrast(p.onAccent, p.accent), greaterThanOrEqualTo(4.5));
  });

  test('modifiers and notes never look like allergens', () {
    for (final seed in PaletteSeed.presets) {
      for (final dark in [true, false]) {
        final p = Palette.from(seed, dark: dark);
        expect(isRedLike(p.primary), isFalse, reason: '${seed.name}: modifier colour is red');
      }
    }
  });

  test('hex parsing', () {
    expect(parseHex('#ed1c24'), const Color(0xFFED1C24));
    expect(parseHex('ED1C24'), const Color(0xFFED1C24));
    expect(parseHex('#12345'), isNull);
    expect(hexOf(const Color(0xFFED1C24)), '#ED1C24');
  });
}
