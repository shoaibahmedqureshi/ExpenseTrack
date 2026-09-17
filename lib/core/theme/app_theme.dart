import 'package:flutter/material.dart';

// Color values and font match the "Fiscal Precision" Stitch design system
// (Manrope font, deep teal #005F55) — same constant names as before so
// every screen that already references AppTheme.primaryColor/etc. picks up
// the new palette without needing its own edits. Purely visual: no
// screen's behavior changed. Supersedes the earlier "Teal & Precision"
// (Hanken Grotesk) pass.
class AppTheme {
  AppTheme._();

  static const Color primaryColor = Color(0xFF005F55);
  static const Color accentColor = Color(0xFFDC3128);
  static const Color backgroundColor = Color(0xFFFBF9F8);
  static const Color cardColor = Colors.white;
  static const Color textPrimary = Color(0xFF1B1C1C);
  // "outline" in the spec — muted labels, dates, hints.
  static const Color textSecondary = Color(0xFF6E7976);
  static const Color incomeColor = Color(0xFF006318);
  static const Color expenseColor = Color(0xFFB81311);

  // Darker muted tone — body-weight secondary copy (greeting text, card
  // eyebrow labels), distinct from the lighter "outline" above.
  static const Color onSurfaceVariant = Color(0xFF3E4946);
  static const Color surfaceContainer = Color(0xFFEFEDED);
  static const Color outlineVariant = Color(0xFFBDC9C5);
  static const Color onPrimaryContainer = Color(0xFFABFFEF);
  static const Color tertiaryContainerText = Color(0xFF107E26);
  // Third progress-bar tier for "near limit but not yet over" (the spec's
  // "caution" state, e.g. a budget at 90%+ but not over).
  static const Color cautionColor = Color(0xFFF59E0B);

  static const String fontFamily = 'Manrope';

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        surface: backgroundColor,
      ),
      scaffoldBackgroundColor: backgroundColor,
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 2,
        shadowColor: primaryColor.withOpacity(0.08),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 64,
        // display-md (24px/700/-0.01em), matching the spec's AppBar title.
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: -0.24,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
