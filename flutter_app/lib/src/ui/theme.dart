import 'package:flutter/material.dart';

/// UNIPOS Staff design tokens, dark theme.
abstract final class K {
  static const accent = Color(0xFFC67139);
  static const onAccent = Color(0xFFFFFFFF);
  static const paper = Color(0xFF221B14);
  static const paperBar = Color(0xFF2E251C);
  static const card = Color(0xFF2B231B);
  static const key = Color(0xFF3D332D);
  static const ink = Color(0xFFF0DFD7);
  static const white = Color(0xFFFFFFFF);
  static const muted = Color(0xFFB3A18B);
  static const ok = Color(0xFF6FBFA6);
  static const bad = Color(0xFFE08373);
  static const badGround = Color(0xFF3B211B);
  static const primary = Color(0xFFFFB68B);
  static const primaryContainer = Color(0xFF6F3811);
  static const onPrimaryContainer = Color(0xFFFFDBC8);
  static const outline = Color(0xFF9F8D84);
  static const outlineVariant = Color(0xFF52443C);
  static const inverseSurface = Color(0xFFF0DFD7);
  static const inverseInk = Color(0xFF382E29);

  static const radius = BorderRadius.all(Radius.circular(12));
  static const radiusPill = BorderRadius.all(Radius.circular(20));
  static const radius14 = BorderRadius.all(Radius.circular(14));

  static const mono = ['Menlo', 'Roboto Mono', 'monospace'];

  static ThemeData theme() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(seedColor: accent, brightness: Brightness.dark).copyWith(
        surface: card,
        onSurface: ink,
        outline: outline,
        outlineVariant: outlineVariant,
        primary: primary,
      ),
      scaffoldBackgroundColor: paper,
      appBarTheme: const AppBarTheme(backgroundColor: paperBar, foregroundColor: white, elevation: 0, scrolledUnderElevation: 0),
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
          side: const BorderSide(color: outline),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          shape: const RoundedRectangleBorder(borderRadius: radius),
          padding: const EdgeInsets.symmetric(horizontal: 18),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: key,
        border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: outline)),
        enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: outline)),
        focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: primary, width: 2)),
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        labelStyle: TextStyle(color: muted),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? white : outline),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? accent : key),
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
