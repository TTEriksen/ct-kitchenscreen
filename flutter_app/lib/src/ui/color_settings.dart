import 'package:flutter/material.dart';

import '../models.dart';
import 'palette.dart';
import 'theme.dart';

/// Settings › Farver: light/dark mode, five palettes and one of your own,
/// with a live preview of both modes and the contrast each pair reaches.
class ColorSettings extends StatefulWidget {
  const ColorSettings({super.key, required this.settings, required this.onChanged});

  /// Edited in place; [onChanged] tells the page to repaint.
  final Settings settings;
  final VoidCallback onChanged;

  @override
  State<ColorSettings> createState() => _ColorSettingsState();
}

class _ColorSettingsState extends State<ColorSettings> {
  Settings get s => widget.settings;
  late final _hex = TextEditingController(text: hexOf(Color(s.customAccent)));

  static const _swatches = [
    0xFFED1C24, 0xFFC67139, 0xFFE39A0E, 0xFF16915A, 0xFF0F8B8D, 0xFF2463D6,
    0xFF5B4BDB, 0xFFB0327A, 0xFF7A5230, 0xFF4A5560,
  ];

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  void _set(VoidCallback f) {
    setState(f);
    widget.onChanged();
  }

  void _setAccent(Color c) => _set(() {
        s.customAccent = c.toARGB32();
        final h = hexOf(c);
        if (_hex.text.toUpperCase() != h) _hex.text = h;
      });

  @override
  Widget build(BuildContext context) {
    final seed = K.seedOf(s);
    final presets = [...PaletteSeed.presets, K.seedOf(s.copy()..palette = 'custom')];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: K.card, borderRadius: K.radius14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.palette_outlined, color: K.primary, size: 26),
          const SizedBox(width: 10),
          Text('Farver', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: K.strong)),
        ]),
        const SizedBox(height: 16),

        Text('Visning', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: K.ink)),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 'dark', icon: Icon(Icons.dark_mode_outlined), label: Text('Mørk')),
            ButtonSegment(value: 'light', icon: Icon(Icons.light_mode_outlined), label: Text('Lys')),
            ButtonSegment(value: 'auto', icon: Icon(Icons.brightness_auto_outlined), label: Text('Automatisk')),
          ],
          selected: {s.themeMode},
          onSelectionChanged: (v) => _set(() => s.themeMode = v.first),
        ),
        const SizedBox(height: 6),
        Text('Automatisk følger tablettens egen indstilling for lys og mørk.', style: TextStyle(fontSize: 14, color: K.muted)),
        const SizedBox(height: 20),

        Text('Palet', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: K.ink)),
        const SizedBox(height: 8),
        Wrap(spacing: 12, runSpacing: 12, children: [
          for (final p in presets) _PaletteCard(seed: p, selected: s.palette == p.id, onTap: () => _set(() => s.palette = p.id)),
        ]),

        if (s.palette == 'custom') ...[
          const SizedBox(height: 20),
          _customEditor(),
        ],

        const SizedBox(height: 20),
        Text('Forhåndsvisning', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: K.ink)),
        const SizedBox(height: 8),
        LayoutBuilder(builder: (context, c) {
          final dark = Palette.from(seed, dark: true);
          final light = Palette.from(seed, dark: false);
          final previews = [
            _Preview(palette: dark, title: 'Mørk'),
            _Preview(palette: light, title: 'Lys'),
          ];
          return c.maxWidth > 760
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: previews[0]),
                  const SizedBox(width: 16),
                  Expanded(child: previews[1]),
                ])
              : Column(children: [previews[0], const SizedBox(height: 16), previews[1]]);
        }),
      ]),
    );
  }

  Widget _customEditor() {
    final accent = Color(s.customAccent);
    final hsl = HSLColor.fromColor(accent);
    Widget slider(String label, double value, double max, ValueChanged<double> onChanged, {String? valueText}) => Row(children: [
          SizedBox(width: 150, child: Text(label, style: TextStyle(fontSize: 15, color: K.ink))),
          Expanded(child: Slider(value: value.clamp(0, max), max: max, onChanged: onChanged)),
          SizedBox(width: 56, child: Text(valueText ?? '${value.round()}', textAlign: TextAlign.right, style: TextStyle(fontSize: 15, color: K.muted))),
        ]);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: K.paper, borderRadius: K.radius, border: Border.all(color: K.outlineVariant)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Egen accentfarve', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: K.strong)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          for (final c in _swatches)
            Semantics(
              button: true,
              label: hexOf(Color(c)),
              child: InkWell(
                onTap: () => _setAccent(Color(c)),
                borderRadius: K.radiusControl,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Color(c),
                    borderRadius: K.radiusControl,
                    border: Border.all(color: c == s.customAccent ? K.strong : K.outlineVariant, width: c == s.customAccent ? 3 : 1),
                  ),
                ),
              ),
            ),
          SizedBox(
            width: 150,
            child: TextField(
              controller: _hex,
              style: TextStyle(fontSize: 18, color: K.ink),
              decoration: const InputDecoration(labelText: 'Hex', hintText: '#ED1C24'),
              onChanged: (v) {
                final c = parseHex(v);
                if (c != null) _set(() => s.customAccent = c.toARGB32());
              },
            ),
          ),
        ]),
        const SizedBox(height: 8),
        slider('Farvetone', hsl.hue, 360, (v) => _setAccent(hsl.withHue(v).toColor()), valueText: '${hsl.hue.round()}°'),
        slider('Mætning', hsl.saturation * 100, 100, (v) => _setAccent(hsl.withSaturation(v / 100).toColor()), valueText: '${(hsl.saturation * 100).round()} %'),
        slider('Lyshed', hsl.lightness * 100, 100, (v) => _setAccent(hsl.withLightness(v / 100).toColor()), valueText: '${(hsl.lightness * 100).round()} %'),
        const SizedBox(height: 12),
        Text('Baggrundens tone', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: K.strong)),
        const SizedBox(height: 4),
        slider('Farvetone', s.customNeutralHue, 360, (v) => _set(() => s.customNeutralHue = v), valueText: '${s.customNeutralHue.round()}°'),
        slider('Styrke', s.customNeutralTint * 100, 40, (v) => _set(() => s.customNeutralTint = v / 100),
            valueText: s.customNeutralTint == 0 ? 'Grå' : '${(s.customNeutralTint * 100).round()} %'),
        const SizedBox(height: 4),
        Text(
          'Knapper, tekst, allergier og statusfarver beregnes automatisk ud fra dine valg til både mørk og lys visning, '
          'og justeres så de altid kan læses (mindst 4,5:1).',
          style: TextStyle(fontSize: 14, height: 1.4, color: K.muted),
        ),
      ]),
    );
  }
}

class _PaletteCard extends StatelessWidget {
  const _PaletteCard({required this.seed, required this.selected, required this.onTap});
  final PaletteSeed seed;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Palette.from(seed, dark: true);
    final light = Palette.from(seed, dark: false);
    Widget strip(Palette p) => Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          color: p.paper,
          child: Row(children: [
            for (final c in [p.card, p.accent, p.ok, p.warn, p.bad])
              Container(
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: p.outlineVariant)),
              ),
          ]),
        );

    return Semantics(
      button: true,
      selected: selected,
      label: 'Palet ${seed.name}',
      child: InkWell(
        onTap: onTap,
        borderRadius: K.radius,
        child: Container(
          width: 230,
          decoration: BoxDecoration(
            color: K.paper,
            borderRadius: K.radius,
            border: Border.all(color: selected ? K.accent : K.outlineVariant, width: selected ? 3 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            strip(dark),
            strip(light),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(seed.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: K.strong))),
                  if (selected) Icon(Icons.check_circle, color: K.primary, size: 22),
                ]),
                const SizedBox(height: 4),
                Text(seed.description, style: TextStyle(fontSize: 13, color: K.muted)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// A small ticket drawn in [palette], with the contrast of each text pair.
class _Preview extends StatelessWidget {
  const _Preview({required this.palette, required this.title});
  final Palette palette;
  final String title;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    TextStyle t(double size, Color c, [FontWeight w = FontWeight.w600]) => TextStyle(fontSize: size, color: c, fontWeight: w, height: 1.25);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: p.paper, borderRadius: K.radius, border: Border.all(color: K.outlineVariant)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title, style: t(15, p.muted, FontWeight.w700)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: p.card, borderRadius: K.radius, border: Border.all(color: p.outlineVariant)),
          clipBehavior: Clip.antiAlias,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              color: p.paperBar,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(children: [
                Text('Bord ', style: t(15, p.muted)),
                Text('12', style: t(30, p.strong, FontWeight.w800)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(borderRadius: K.radiusPill, border: Border.all(color: p.warn, width: 2)),
                  child: Text('12 min', style: t(14, p.warn, FontWeight.w700)),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: p.bad, borderRadius: K.radiusPill),
                  child: Text('18 min', style: t(14, p.onBad, FontWeight.w700)),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Bon 1041 · 4 pers. · Mette', style: t(13, p.muted, FontWeight.w400)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: p.badGround, borderRadius: K.radius, border: Border.all(color: p.bad, width: 2)),
                  child: Row(children: [
                    Icon(Icons.warning_amber_outlined, color: p.bad, size: 20),
                    const SizedBox(width: 6),
                    Expanded(child: Text('Allergi: gluten', style: t(15, p.bad, FontWeight.w800))),
                  ]),
                ),
                const SizedBox(height: 8),
                Text('2 ×  Wienerschnitzel', style: t(19, p.ink)),
                Padding(padding: const EdgeInsets.only(left: 34), child: Text('Uden kapers', style: t(15, p.primary))),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: p.primaryContainer, borderRadius: K.radius),
                  child: Text('Note: børneretten først', style: t(15, p.onPrimaryContainer)),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: p.accent, borderRadius: K.radius),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.check_circle_outline, color: p.onAccent, size: 20),
                    const SizedBox(width: 6),
                    Text('Færdig', style: t(17, p.onAccent, FontWeight.w700)),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        for (final c in p.checks)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(children: [
              Icon(c.ratio >= c.need ? Icons.check_circle_outline : Icons.error_outline, size: 16, color: c.ratio >= c.need ? p.ok : p.bad),
              const SizedBox(width: 6),
              Expanded(child: Text(c.label, style: t(13, p.ink, FontWeight.w400))),
              Text('${c.ratio.toStringAsFixed(1).replaceAll('.', ',')}:1', style: t(13, p.muted, FontWeight.w600)),
            ]),
          ),
      ]),
    );
  }
}
