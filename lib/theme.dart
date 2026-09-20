import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The "Fersk" visual direction: a deep teal primary (deliberately NOT a
/// grass-green — that read as near-identical to competitor SeSum's own
/// green once seen live), a coral savings-accent reserved for the app's one
/// big "go do this" moment (see [savingsAccent] and where it's used), and a
/// friendly display face paired with a calm body face. Deliberately doesn't
/// yet touch how price figures/list rows are set (the "kvittering"
/// receipt-line styling) — that part is tied to the Handletur/trip screens,
/// which are still due to change once real routing (Fase B) lands, so it
/// stays a separate pass.
class AppTheme {
  AppTheme._();

  static const _primary = Color(0xFF1B5E63);
  static const _onPrimary = Color(0xFFF2F8F7);
  static const _background = Color(0xFFF2F4F0);

  /// Reserved for the app's single biggest call-to-action per screen (e.g.
  /// "Bekreft rute og start handletur") and for savings emphasis — not a
  /// general secondary color, so most buttons should keep using the
  /// default (primary-colored) FilledButton rather than reaching for this.
  static const savingsAccent = Color(0xFFD8543C);
  static const onSavingsAccent = Color(0xFFFFF6F1);

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: _primary,
      onPrimary: _onPrimary,
      secondary: savingsAccent,
      onSecondary: onSavingsAccent,
      surface: _background,
    );

    final baseTextTheme = ThemeData(brightness: Brightness.light).textTheme;
    final textTheme = GoogleFonts.workSansTextTheme(baseTextTheme).copyWith(
      displayLarge: GoogleFonts.bricolageGrotesque(textStyle: baseTextTheme.displayLarge, fontWeight: FontWeight.w700),
      displayMedium: GoogleFonts.bricolageGrotesque(textStyle: baseTextTheme.displayMedium, fontWeight: FontWeight.w700),
      displaySmall: GoogleFonts.bricolageGrotesque(textStyle: baseTextTheme.displaySmall, fontWeight: FontWeight.w700),
      headlineLarge: GoogleFonts.bricolageGrotesque(textStyle: baseTextTheme.headlineLarge, fontWeight: FontWeight.w700),
      headlineMedium: GoogleFonts.bricolageGrotesque(textStyle: baseTextTheme.headlineMedium, fontWeight: FontWeight.w700),
      headlineSmall: GoogleFonts.bricolageGrotesque(textStyle: baseTextTheme.headlineSmall, fontWeight: FontWeight.w700),
      titleLarge: GoogleFonts.bricolageGrotesque(textStyle: baseTextTheme.titleLarge, fontWeight: FontWeight.w600),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _background,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: _primary,
        foregroundColor: _onPrimary,
        titleTextStyle: GoogleFonts.bricolageGrotesque(fontWeight: FontWeight.w700, fontSize: 20, color: _onPrimary),
      ),
    );
  }
}
