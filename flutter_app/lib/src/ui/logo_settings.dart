import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../kitchen.dart';
import '../models.dart';
import 'palette.dart';
import 'theme.dart';
import 'venue_logo.dart';

/// Logo images picked in settings but not saved yet.
class LogoDraft {
  LogoDraft(Kitchen k)
      : dark = k.logoDark,
        light = k.logoLight;
  Uint8List? dark;
  Uint8List? light;
  bool darkChanged = false;
  bool lightChanged = false;

  Future<void> save(Kitchen k) async {
    if (darkChanged) await k.setLogo(dark: true, bytes: dark);
    if (lightChanged) await k.setLogo(dark: false, bytes: light);
    darkChanged = lightChanged = false;
  }
}

/// Settings › Logo: CTpos or the venue's own logo in the top bar.
class LogoSettings extends StatefulWidget {
  const LogoSettings({super.key, required this.settings, required this.draft, required this.onChanged});
  final Settings settings;
  final LogoDraft draft;
  final VoidCallback onChanged;

  @override
  State<LogoSettings> createState() => _LogoSettingsState();
}

class _LogoSettingsState extends State<LogoSettings> {
  String? _error;

  Settings get s => widget.settings;
  LogoDraft get d => widget.draft;

  void _set(VoidCallback f) {
    setState(f);
    widget.onChanged();
  }

  Future<void> _pick(bool dark) async {
    setState(() => _error = null);
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, maxHeight: 600);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      // Make sure it is an image Flutter can draw before accepting it.
      final codec = await ui.instantiateImageCodec(bytes);
      codec.dispose();
      _set(() {
        if (dark) {
          d.dark = bytes;
          d.darkChanged = true;
        } else {
          d.light = bytes;
          d.lightChanged = true;
        }
        s.logo = 'custom';
      });
    } catch (e) {
      setState(() => _error = 'Billedet kunne ikke bruges. Vælg en PNG eller JPG.');
    }
  }

  void _remove(bool dark) => _set(() {
        if (dark) {
          d.dark = null;
          d.darkChanged = true;
        } else {
          d.light = null;
          d.lightChanged = true;
        }
      });

  @override
  Widget build(BuildContext context) {
    final custom = s.logo == 'custom';
    final seed = K.seedOf(s);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: K.card, borderRadius: K.radius14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.image_outlined, color: K.primary, size: 26),
          const SizedBox(width: 10),
          Text('Logo i topbjælken', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: K.strong)),
        ]),
        const SizedBox(height: 16),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 'ctpos', label: Text('CTpos')),
            ButtonSegment(value: 'custom', label: Text('Eget logo')),
          ],
          selected: {s.logo},
          onSelectionChanged: (v) => _set(() => s.logo = v.first),
        ),
        const SizedBox(height: 6),
        Text('Appens ikon og startskærm er altid CTpos.', style: TextStyle(fontSize: 14, color: K.muted)),
        if (custom) ...[
          const SizedBox(height: 16),
          Wrap(spacing: 16, runSpacing: 16, children: [
            _slot('Til mørk visning', 'Lyst logo, fx hvid tekst', d.dark, d.light, Palette.from(seed, dark: true), true),
            _slot('Til lys visning', 'Mørkt logo, fx sort tekst', d.light, d.dark, Palette.from(seed, dark: false), false),
          ]),
          const SizedBox(height: 8),
          Text(
            'Har du kun ét logo, bruges det i begge visninger. Brug gerne en PNG med gennemsigtig baggrund, højst 1600 × 600 punkter.',
            style: TextStyle(fontSize: 14, height: 1.4, color: K.muted),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: K.bad)),
          ],
        ],
      ]),
    );
  }

  /// One upload slot, previewed on the top bar colour of that mode.
  Widget _slot(String title, String hint, Uint8List? own, Uint8List? other, Palette p, bool dark) {
    final shown = own ?? other;
    return SizedBox(
      width: 330,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: K.strong)),
        Text(own == null && other != null ? 'Bruger det andet logo' : hint, style: TextStyle(fontSize: 13, color: K.muted)),
        const SizedBox(height: 8),
        Container(
          height: 88,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(color: p.paperBar, borderRadius: K.radius, border: Border.all(color: K.outlineVariant)),
          child: shown == null
              ? Text('Intet billede valgt', style: TextStyle(fontSize: 15, color: p.muted))
              : logoImage(shown, 48),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _pick(dark),
              icon: const Icon(Icons.upload_outlined),
              label: Text(own == null ? 'Vælg billede' : 'Skift billede'),
            ),
          ),
          if (own != null) ...[
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => _remove(dark),
              style: OutlinedButton.styleFrom(foregroundColor: K.bad, side: BorderSide(color: K.bad)),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Fjern'),
            ),
          ],
        ]),
      ]),
    );
  }
}
