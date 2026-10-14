'use strict';

// Colour palettes for the kitchen screen: the same calculation as the tablet app
// (flutter_app/lib/src/ui/palette.dart). A palette is an accent colour plus a
// neutral tone; every other colour is derived for dark or light mode, and each
// pair that carries text is pushed until it reaches a readable contrast.
(function (root) {
  const PRESETS = [
    { id: 'ctpos', name: 'CTpos', description: 'CT-rød på blæk. Husets farver.', accent: '#ED1C24', neutralHue: 0, neutralTint: 0 },
    { id: 'brasserie', name: 'Brasserie', description: 'Brændt orange på varm brun.', accent: '#C67139', neutralHue: 30, neutralTint: 0.22 },
    { id: 'hav', name: 'Hav', description: 'Klar blå på skifergrå.', accent: '#2463D6', neutralHue: 215, neutralTint: 0.16 },
    { id: 'skov', name: 'Skov', description: 'Dyb grøn på mosgrå.', accent: '#16915A', neutralHue: 150, neutralTint: 0.10 },
    { id: 'kontrast', name: 'Høj kontrast', description: 'Rav på ren sort og hvid. Til stærkt lys.', accent: '#E39A0E', neutralHue: 0, neutralTint: 0 },
  ];

  // ---------- Colour maths (sRGB, HSL, WCAG contrast) ----------
  function hexToRgb(hex) {
    const t = String(hex).trim().replace('#', '');
    if (!/^[0-9a-fA-F]{6}$/.test(t)) return null;
    const n = parseInt(t, 16);
    return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
  }
  const rgbToHex = (c) => '#' + c.map((v) => Math.round(Math.max(0, Math.min(255, v))).toString(16).padStart(2, '0')).join('').toUpperCase();

  function rgbToHsl([r, g, b]) {
    r /= 255; g /= 255; b /= 255;
    const max = Math.max(r, g, b);
    const min = Math.min(r, g, b);
    const l = (max + min) / 2;
    let h = 0;
    let s = 0;
    if (max !== min) {
      const d = max - min;
      s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
      if (max === r) h = ((g - b) / d + (g < b ? 6 : 0)) * 60;
      else if (max === g) h = ((b - r) / d + 2) * 60;
      else h = ((r - g) / d + 4) * 60;
    }
    return { h, s, l };
  }

  function hslToRgb({ h, s, l }) {
    const c = (1 - Math.abs(2 * l - 1)) * s;
    const hp = (((h % 360) + 360) % 360) / 60;
    const x = c * (1 - Math.abs((hp % 2) - 1));
    let rgb = [0, 0, 0];
    if (hp < 1) rgb = [c, x, 0];
    else if (hp < 2) rgb = [x, c, 0];
    else if (hp < 3) rgb = [0, c, x];
    else if (hp < 4) rgb = [0, x, c];
    else if (hp < 5) rgb = [x, 0, c];
    else rgb = [c, 0, x];
    const m = l - c / 2;
    return rgb.map((v) => (v + m) * 255);
  }

  const hsl = (h, s, l) => hslToRgb({ h, s, l });

  function luminance(rgb) {
    const [r, g, b] = rgb.map((v) => {
      const c = v / 255;
      return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
    });
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /** WCAG 2 contrast ratio (1–21). */
  function contrast(a, b) {
    const la = luminance(a);
    const lb = luminance(b);
    return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
  }

  const lerp = (a, b, t) => a.map((v, i) => v + (b[i] - v) * t);

  /** Moves fg's lightness away from bg until the pair reaches ratio; keeps hue and saturation. */
  function ensureContrast(fg, bg, ratio) {
    if (contrast(fg, bg) >= ratio) return fg;
    const c = rgbToHsl(fg);
    const lighter = luminance(bg) < 0.5;
    let l = c.l;
    for (let i = 0; i < 100; i++) {
      l = Math.max(0, Math.min(1, l + (lighter ? 0.01 : -0.01)));
      const out = hslToRgb({ h: c.h, s: c.s, l });
      if (contrast(out, bg) >= ratio || l === 0 || l === 1) return out;
    }
    return hslToRgb({ h: c.h, s: c.s, l });
  }

  /** True for a clearly red colour: within 15° of the allergen red and saturated. */
  function isRedLike(rgb) {
    const c = rgbToHsl(rgb);
    const d = Math.abs(c.h - 6);
    return Math.min(d, 360 - d) < 15 && c.s > 0.35 && c.l > 0.15 && c.l < 0.85;
  }

  // ---------- The palette ----------
  function compute(seed, dark) {
    const h = seed.neutralHue || 0;
    const s = Math.max(0, Math.min(0.4, seed.neutralTint || 0));
    const n = (l, sat = 1) => hsl(h, s * sat, l);
    const base = hexToRgb(seed.accent) || hexToRgb('#ED1C24');

    const paper = dark ? n(0.075) : n(0.955);
    const bar = dark ? n(0.115) : n(0.905);
    const card = dark ? n(0.125) : n(0.995, 0.5);
    const key = dark ? n(0.20) : n(0.885);
    const outlineVariant = dark ? n(0.27) : n(0.82);
    const outline = ensureContrast(dark ? n(0.55) : n(0.50), card, 3);

    const strong = dark ? [255, 255, 255] : n(0.06);
    const ink = ensureContrast(dark ? n(0.90, 0.6) : n(0.13), card, 10);
    const muted = ensureContrast(dark ? n(0.68, 0.7) : n(0.40, 0.7), card, 4.5);

    const white = [255, 255, 255];
    const black = n(0.06);
    const useWhite = contrast(white, base) >= contrast(black, base) || (contrast(white, base) >= 3 && rgbToHsl(base).l < 0.62);
    const onAccent = useWhite ? white : black;
    const accent = ensureContrast(base, onAccent, 4.5);

    // Red belongs to allergens: with a red accent, modifiers and notes use the CTpos info blue.
    const textSeed = isRedLike(base) ? hexToRgb('#2463D6') : base;
    const ts = rgbToHsl(textSeed);
    const primary = ensureContrast(hslToRgb({ h: ts.h, s: ts.s, l: Math.max(0, Math.min(1, ts.l + (dark ? 0.12 : -0.08))) }), card, 4.5);
    const primaryContainer = lerp(card, textSeed, dark ? 0.32 : 0.16);
    const onPrimaryContainer = ensureContrast(lerp(textSeed, strong, dark ? 0.8 : 0.75), primaryContainer, 7);

    const ok = ensureContrast(hsl(158, 0.55, dark ? 0.58 : 0.30), card, 4.5);
    const warn = ensureContrast(hsl(38, 0.90, dark ? 0.58 : 0.34), card, 4.5);
    const badBase = hsl(6, 0.72, dark ? 0.68 : 0.40);
    const badGround = lerp(card, badBase, dark ? 0.16 : 0.09);
    const bad = ensureContrast(ensureContrast(badBase, card, 4.5), badGround, 4.5);
    const onBad = contrast(white, bad) >= contrast(black, bad) ? white : black;

    const p = {
      dark, accent, onAccent, paper, paperBar: bar, card, key, ink, strong, muted, ok, warn, bad, onBad, badGround,
      primary, primaryContainer, onPrimaryContainer, outline, outlineVariant,
      inverseSurface: dark ? n(0.90, 0.6) : n(0.18), inverseInk: dark ? n(0.12) : n(0.95),
    };
    p.checks = [
      { label: 'Tekst på bon', ratio: contrast(ink, card) },
      { label: 'Sekundær tekst', ratio: contrast(muted, card) },
      { label: 'Knaptekst', ratio: contrast(onAccent, accent) },
      { label: 'Tilvalg', ratio: contrast(primary, card) },
      { label: 'Allergi', ratio: contrast(bad, badGround) },
      { label: 'Note', ratio: contrast(onPrimaryContainer, primaryContainer) },
    ];
    return p;
  }

  function seedOf(settings) {
    if (settings.palette === 'custom') {
      return { id: 'custom', name: 'Egen', description: 'Dine egne farver.', accent: settings.customAccent || '#ED1C24', neutralHue: Number(settings.customNeutralHue) || 0, neutralTint: Number(settings.customNeutralTint) || 0 };
    }
    return PRESETS.find((p) => p.id === settings.palette) || PRESETS[0];
  }

  function isDark(settings) {
    if (settings.themeMode === 'light') return false;
    if (settings.themeMode === 'auto') return !window.matchMedia('(prefers-color-scheme: light)').matches;
    return true;
  }

  const VARS = {
    accent: '--accent', onAccent: '--on-accent', paper: '--paper', paperBar: '--paper-bar', card: '--card', key: '--key',
    ink: '--ink', strong: '--strong', muted: '--muted', ok: '--ok', warn: '--warn', bad: '--bad', onBad: '--on-bad',
    badGround: '--bad-ground', primary: '--primary', primaryContainer: '--primary-container',
    onPrimaryContainer: '--on-primary-container', outline: '--outline', outlineVariant: '--outline-variant',
    inverseSurface: '--inverse-surface', inverseInk: '--inverse-ink',
  };

  /** Writes the palette as CSS variables on :root and returns it. */
  function apply(settings) {
    const p = compute(seedOf(settings), isDark(settings));
    const st = document.documentElement.style;
    for (const [k, v] of Object.entries(VARS)) st.setProperty(v, rgbToHex(p[k]));
    st.setProperty('color-scheme', p.dark ? 'dark' : 'light');
    document.documentElement.dataset.theme = p.dark ? 'dark' : 'light';
    const meta = document.querySelector('meta[name="theme-color"]');
    if (meta) meta.setAttribute('content', rgbToHex(p.paperBar));
    return p;
  }

  root.KDSPalette = { PRESETS, compute, seedOf, isDark, apply, contrast, hexToRgb, rgbToHex, rgbToHsl, hslToRgb, isRedLike };
  if (typeof module !== 'undefined') module.exports = root.KDSPalette;
})(typeof window !== 'undefined' ? window : globalThis);
