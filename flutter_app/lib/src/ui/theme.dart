import 'package:flutter/material.dart';

import '../models.dart';
import 'palette.dart';

/// Colours of the active palette (CTpos design system by default), plus the
/// shapes and fonts that do not change with it. The app sets [K.p] from the
/// saved settings before every build, so widgets read colours straight from K.
abstract final class K {
  static Palette p = Palette.from(PaletteSeed.presets.first, dark: true);

  /// The palette chosen in settings, resolved for dark or light mode.
  static Palette resolve(Settings s, Brightness platform) {
    final dark = switch (s.themeMode) { 'light' => false, 'auto' => platform == Brightness.dark, _ => true };
    return Palette.from(seedOf(s), dark: dark);
  }

  static PaletteSeed seedOf(Settings s) => s.palette == 'custom'
      ? PaletteSeed(
          id: 'custom',
          name: 'Egen',
          description: 'Dine egne farver.',
          accent: Color(s.customAccent),
          neutralHue: s.customNeutralHue,
          neutralTint: s.customNeutralTint,
        )
      : PaletteSeed.byId(s.palette);

  static Color get accent => p.accent;
  static Color get onAccent => p.onAccent;
  static Color get paper => p.paper;
  static Color get paperBar => p.paperBar;
  static Color get card => p.card;
  static Color get key => p.key;
  static Color get ink => p.ink;
  static Color get strong => p.strong;
  static Color get muted => p.muted;
  static Color get ok => p.ok;
  static Color get warn => p.warn;
  static Color get bad => p.bad;
  static Color get onBad => p.onBad;
  static Color get badGround => p.badGround;
  static Color get primary => p.primary;
  static Color get primaryContainer => p.primaryContainer;
  static Color get onPrimaryContainer => p.onPrimaryContainer;
  static Color get outline => p.outline;
  static Color get outlineVariant => p.outlineVariant;
  static Color get inverseSurface => p.inverseSurface;
  static Color get inverseInk => p.inverseInk;

  /// CTpos wordmark: white on dark grounds, black on light ones (red bar in both).
  static String get logo => p.dark ? 'assets/ctpos_reversed.png' : 'assets/ctpos_color.png';

  // Radii from the CTpos design system: controls 6, cards 10, dialogs 16.
  static const radius = BorderRadius.all(Radius.circular(10));
  static const radiusControl = BorderRadius.all(Radius.circular(6));
  static const radiusPill = BorderRadius.all(Radius.circular(20));
  static const radius14 = BorderRadius.all(Radius.circular(16));

  static const mono = ['Menlo', 'Roboto Mono', 'monospace'];

  static ThemeData theme() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: p.dark ? Brightness.dark : Brightness.light,
      colorScheme: ColorScheme.fromSeed(seedColor: accent, brightness: p.dark ? Brightness.dark : Brightness.light).copyWith(
        surface: card,
        onSurface: ink,
        outline: outline,
        outlineVariant: outlineVariant,
        primary: primary,
      ),
      scaffoldBackgroundColor: paper,
      appBarTheme: AppBarTheme(backgroundColor: paperBar, foregroundColor: strong, elevation: 0, scrolledUnderElevation: 0),
      dividerColor: outlineVariant,
    );
    return base.copyWith(
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: onAccent,
          minimumSize: const Size(64, 56),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          shape: const RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size(58, 58),
          side: BorderSide(color: outline),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          shape: const RoundedRectangleBorder(borderRadius: radius),
          padding: const EdgeInsets.symmetric(horizontal: 18),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: key,
        border: OutlineInputBorder(borderRadius: radiusControl, borderSide: BorderSide(color: outline)),
        enabledBorder: OutlineInputBorder(borderRadius: radiusControl, borderSide: BorderSide(color: outline)),
        focusedBorder: OutlineInputBorder(borderRadius: radiusControl, borderSide: BorderSide(color: primary, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        labelStyle: TextStyle(color: muted),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? onAccent : outline),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? accent : key),
      ),
      sliderTheme: SliderThemeData(activeTrackColor: accent, thumbColor: accent, inactiveTrackColor: key),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: accent,
          selectedForegroundColor: onAccent,
          foregroundColor: ink,
          side: BorderSide(color: outline),
          minimumSize: const Size(64, 52),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

enum Tone { ok, warn, late }

Tone toneOf(int minutes, int warn, int late) {
  if (minutes >= late) return Tone.late;
  if (minutes >= warn) return Tone.warn;
  return Tone.ok;
}

String hhmm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
