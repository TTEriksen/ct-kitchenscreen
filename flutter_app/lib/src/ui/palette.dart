import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A colour scheme is calculated from two choices: an accent colour (buttons,
/// highlights) and a neutral tone (the grounds and text, tinted slightly towards
/// one hue). Everything else is derived for dark or light mode, and every pair
/// that carries text is pushed until it reaches a readable contrast.
class PaletteSeed {
  const PaletteSeed({
    required this.id,
    required this.name,
    required this.description,
    required this.accent,
    required this.neutralHue,
    required this.neutralTint,
  });

  final String id;
  final String name;
  final String description;
  final Color accent;

  /// Hue (0–360) the greys lean towards, and how much (0 = pure grey, 0.3 = clearly tinted).
  final double neutralHue;
  final double neutralTint;

  static const presets = [
    PaletteSeed(
      id: 'ctpos',
      name: 'CTpos',
      description: 'CT-rød på blæk. Husets farver.',
      accent: Color(0xFFED1C24),
      neutralHue: 0,
      neutralTint: 0,
    ),
    PaletteSeed(
      id: 'brasserie',
      name: 'Brasserie',
      description: 'Brændt orange på varm brun.',
      accent: Color(0xFFC67139),
      neutralHue: 30,
      neutralTint: .22,
    ),
    PaletteSeed(
      id: 'hav',
      name: 'Hav',
      description: 'Klar blå på skifergrå.',
      accent: Color(0xFF2463D6),
      neutralHue: 215,
      neutralTint: .16,
    ),
    PaletteSeed(
      id: 'skov',
      name: 'Skov',
      description: 'Dyb grøn på mosgrå.',
      accent: Color(0xFF16915A),
      neutralHue: 150,
      neutralTint: .10,
    ),
    PaletteSeed(
      id: 'kontrast',
      name: 'Høj kontrast',
      description: 'Rav på ren sort og hvid. Til stærkt lys.',
      accent: Color(0xFFE39A0E),
      neutralHue: 0,
      neutralTint: 0,
    ),
  ];

  static PaletteSeed byId(String id) => presets.firstWhere((p) => p.id == id, orElse: () => presets.first);
}

class Palette {
  Palette._({
    required this.dark,
    required this.accent,
    required this.onAccent,
    required this.paper,
    required this.paperBar,
    required this.card,
    required this.key,
    required this.ink,
    required this.strong,
    required this.muted,
    required this.ok,
    required this.warn,
    required this.bad,
    required this.onBad,
    required this.badGround,
    required this.primary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.outline,
    required this.outlineVariant,
    required this.inverseSurface,
    required this.inverseInk,
  });

  final bool dark;
  final Color accent, onAccent;
  final Color paper, paperBar, card, key;
  final Color ink, strong, muted;
  final Color ok, warn, bad, onBad, badGround;
  final Color primary, primaryContainer, onPrimaryContainer;
  final Color outline, outlineVariant;
  final Color inverseSurface, inverseInk;

  /// Text contrast checks shown under the preview in Settings.
  List<({String label, double ratio, double need})> get checks => [
        (label: 'Tekst på bon', ratio: contrast(ink, card), need: 4.5),
        (label: 'Sekundær tekst', ratio: contrast(muted, card), need: 4.5),
        (label: 'Knaptekst', ratio: contrast(onAccent, accent), need: 4.5),
        (label: 'Tilvalg', ratio: contrast(primary, card), need: 4.5),
        (label: 'Allergi', ratio: contrast(bad, badGround), need: 4.5),
        (label: 'Note', ratio: contrast(onPrimaryContainer, primaryContainer), need: 4.5),
      ];

  factory Palette.from(PaletteSeed seed, {required bool dark}) {
    final h = seed.neutralHue;
    final s = seed.neutralTint.clamp(0.0, .4);
    Color n(double l, [double sat = 1]) => HSLColor.fromAHSL(1, h, s * sat, l).toColor();

    // Grounds and lines.
    final paper = dark ? n(.075) : n(.955);
    final bar = dark ? n(.115) : n(.905);
    final card = dark ? n(.125) : n(.995, .5);
    final key = dark ? n(.20) : n(.885);
    final outlineVariant = dark ? n(.27) : n(.82);
    final outline = ensureContrast(dark ? n(.55) : n(.50), card, 3);

    // Text.
    final strong = dark ? const Color(0xFFFFFFFF) : n(.06);
    final ink = ensureContrast(dark ? n(.90, .6) : n(.13), card, 10);
    final muted = ensureContrast(dark ? n(.68, .7) : n(.40, .7), card, 4.5);

    // Accent: the colour the buttons are filled with, darkened or lightened just
    // enough that its label (white or near black) reads at 4.5:1.
    final white = const Color(0xFFFFFFFF);
    final black = n(.06);
    final useWhite = contrast(white, seed.accent) >= contrast(black, seed.accent) ||
        (contrast(white, seed.accent) >= 3 && _hsl(seed.accent).lightness < .62);
    final onAccent = useWhite ? white : black;
    final accent = ensureContrast(seed.accent, onAccent, 4.5);

    // The accent as text on a card (modifiers, course names) and behind notes.
    // Red belongs to allergens: a red accent would make a modifier look like an
    // allergy, so with a red accent these use the CTpos info blue instead.
    final textSeed = isRedLike(seed.accent) ? const Color(0xFF2463D6) : seed.accent;
    final primary = ensureContrast(_shift(textSeed, dark ? .12 : -.08), card, 4.5);
    final primaryContainer = Color.lerp(card, textSeed, dark ? .32 : .16)!;
    final onPrimaryContainer = ensureContrast(Color.lerp(textSeed, strong, dark ? .8 : .75)!, primaryContainer, 7);

    // Status colours keep fixed hues so they mean the same in every palette.
    final ok = ensureContrast(HSLColor.fromAHSL(1, 158, .55, dark ? .58 : .30).toColor(), card, 4.5);
    final warn = ensureContrast(HSLColor.fromAHSL(1, 38, .90, dark ? .58 : .34).toColor(), card, 4.5);
    final badBase = HSLColor.fromAHSL(1, 6, .72, dark ? .68 : .40).toColor();
    final badGround = Color.lerp(card, badBase, dark ? .16 : .09)!;
    final bad = ensureContrast(ensureContrast(badBase, card, 4.5), badGround, 4.5);
    final onBad = contrast(white, bad) >= contrast(black, bad) ? white : black;

    return Palette._(
      dark: dark,
      accent: accent,
      onAccent: onAccent,
      paper: paper,
      paperBar: bar,
      card: card,
      key: key,
      ink: ink,
      strong: strong,
      muted: muted,
      ok: ok,
      warn: warn,
      bad: bad,
      onBad: onBad,
      badGround: badGround,
      primary: primary,
      primaryContainer: primaryContainer,
      onPrimaryContainer: onPrimaryContainer,
      outline: outline,
      outlineVariant: outlineVariant,
      inverseSurface: dark ? n(.90, .6) : n(.18),
      inverseInk: dark ? n(.12) : n(.95),
    );
  }
}

HSLColor _hsl(Color c) => HSLColor.fromColor(c);

/// True for a clearly red colour: within 15° of the allergen red and saturated.
bool isRedLike(Color c) {
  final h = _hsl(c);
  final d = (h.hue - 6).abs();
  return math.min(d, 360 - d) < 15 && h.saturation > .35 && h.lightness > .15 && h.lightness < .85;
}

Color _shift(Color c, double dl) {
  final h = _hsl(c);
  return h.withLightness((h.lightness + dl).clamp(0.0, 1.0)).toColor();
}

/// WCAG 2 contrast ratio between two colours (1–21).
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + .05) / (math.min(la, lb) + .05);
}

/// Moves [fg]'s lightness away from [bg] in small steps until the pair reaches
/// [ratio]. Keeps hue and saturation, so a brand colour stays recognisable.
Color ensureContrast(Color fg, Color bg, double ratio) {
  if (contrast(fg, bg) >= ratio) return fg;
  final h = _hsl(fg);
  final lighter = bg.computeLuminance() < .5;
  var l = h.lightness;
  for (var i = 0; i < 100; i++) {
    l = (l + (lighter ? .01 : -.01)).clamp(0.0, 1.0);
    final c = h.withLightness(l).toColor();
    if (contrast(c, bg) >= ratio || l == 0 || l == 1) return c;
  }
  return h.withLightness(l).toColor();
}

String hexOf(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

Color? parseHex(String s) {
  final t = s.trim().replaceFirst('#', '');
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(t)) return null;
  return Color(0xFF000000 | int.parse(t, radix: 16));
}
