import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Brand palette (canonical swatches) ──

  static const Color paletteBlack = Color(0xFF000000);
  static const Color palettePrussianBlue = Color(0xFF14213D);
  static const Color paletteOrange = Color(0xFFFCA311);
  static const Color paletteAlabaster = Color(0xFFE5E5E5);
  static const Color paletteWhite = Color(0xFFFFFFFF);

  // ── Light mode ──

  static const Color backgroundLight = paletteWhite;
  static const Color backgroundDark = paletteAlabaster;
  static const Color accentYellow = paletteOrange;
  static const Color accentYellowDark = paletteOrange;
  static const Color cardWhite = paletteWhite;
  static const Color darkButton = palettePrussianBlue;

  // Semantic aliases (same names as before for widgets); each line maps 1:1 to one palette* swatch.
  static const Color textPrimary = paletteBlack;
  static const Color textSecondary = palettePrussianBlue;
  static const Color textTertiary = paletteOrange;
  static const Color textHint = paletteAlabaster;

  // UX semantics outside marketing swatch (accessible success / error)
  static const Color positive = Color(0xFF2E7D32);
  static const Color negative = Color(0xFFC62828);
  static const Color warningColor = paletteOrange;

  static const Color primaryColor = palettePrussianBlue;
  static const Color secondaryColor = paletteOrange;
  static const Color successColor = positive;
  static const Color dangerColor = negative;
  static const Color highlightRed = negative;

  // ── Dark mode ──

  static const Color darkBackground = paletteBlack;
  static const Color _darkBackgroundEnd = palettePrussianBlue;
  static const Color darkCard = palettePrussianBlue;
  static const Color darkSurface = palettePrussianBlue;
  static const Color darkTextPrimary = paletteWhite;
  static const Color darkTextSecondary = paletteAlabaster;
  static const Color darkTextTertiary = paletteOrange;
  static const Color darkBorder = paletteAlabaster;

  static const Color darkPrimary = paletteOrange;
  static const Color darkSecondary = paletteOrange;
  static const Color darkAccent = paletteOrange;
  static const Color darkHighlight = negative;

  static const double cardRadius = 24.0;
  static const double cardRadiusSmall = 16.0;
  static const double buttonRadius = 28.0;

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 24,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> get subtleShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 16,
          offset: const Offset(0, 3),
        ),
      ];

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [backgroundLight, backgroundDark],
  );

  static const LinearGradient darkBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [darkBackground, _darkBackgroundEnd],
  );

  // ── Context-aware helpers ──

  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color cardColor(BuildContext context) =>
      Theme.of(context).colorScheme.surface;

  static Color textPrimaryColor(BuildContext context) =>
      _isDark(context) ? darkTextPrimary : textPrimary;

  static Color textSecondaryColor(BuildContext context) =>
      _isDark(context) ? darkTextSecondary : textSecondary;

  static Color textTertiaryColor(BuildContext context) =>
      _isDark(context) ? darkTextTertiary : textTertiary;

  static Color textHintColor(BuildContext context) =>
      _isDark(context) ? darkBorder : textHint;

  static Color buttonColor(BuildContext context) =>
      _isDark(context) ? darkAccent : darkButton;

  static Color buttonTextColor(BuildContext context) =>
      _isDark(context) ? darkBackground : cardWhite;

  static LinearGradient bgGradient(BuildContext context) =>
      _isDark(context) ? darkBackgroundGradient : backgroundGradient;

  static List<BoxShadow> cardShadowFor(BuildContext context) =>
      _isDark(context) ? const [] : cardShadow;

  static List<BoxShadow> subtleShadowFor(BuildContext context) =>
      _isDark(context) ? const [] : subtleShadow;

  // ── ThemeData definitions ──

  static ThemeData get lightTheme {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
    return base.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        surface: cardWhite,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.inter(fontSize: 36, fontWeight: FontWeight.w800, color: textPrimary, letterSpacing: -0.5),
        displayMedium: GoogleFonts.inter(fontSize: 30, fontWeight: FontWeight.w700, color: textPrimary),
        headlineLarge: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, color: textPrimary),
        headlineMedium: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600, color: textPrimary),
        titleLarge: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary),
        titleMedium: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary),
        bodyLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400, color: textPrimary),
        bodyMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: textSecondary),
        bodySmall: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, color: textTertiary),
        labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent, foregroundColor: textPrimary, elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary),
        iconTheme: const IconThemeData(color: textPrimary, size: 22),
      ),
      cardTheme: CardThemeData(
        elevation: 0, color: cardWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardRadius)),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkButton, foregroundColor: cardWhite, elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius)),
          textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: textHint),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: cardWhite,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: textHint)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: textHint)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: secondaryColor, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent, elevation: 0,
        selectedItemColor: textPrimary, unselectedItemColor: textTertiary,
        showSelectedLabels: false, showUnselectedLabels: false,
      ),
    );
  }

  static ThemeData get darkTheme {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.dark);
    return base.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: ColorScheme.fromSeed(
        seedColor: darkPrimary,
        brightness: Brightness.dark,
        surface: darkCard,
        onSurface: darkTextPrimary,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.inter(fontSize: 36, fontWeight: FontWeight.w800, color: darkTextPrimary, letterSpacing: -0.5),
        displayMedium: GoogleFonts.inter(fontSize: 30, fontWeight: FontWeight.w700, color: darkTextPrimary),
        headlineLarge: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, color: darkTextPrimary),
        headlineMedium: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600, color: darkTextPrimary),
        titleLarge: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: darkTextPrimary),
        titleMedium: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: darkTextPrimary),
        bodyLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400, color: darkTextPrimary),
        bodyMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: darkTextSecondary),
        bodySmall: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, color: darkTextTertiary),
        labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: darkTextPrimary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent, foregroundColor: darkTextPrimary, elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: darkTextPrimary),
        iconTheme: const IconThemeData(color: darkTextPrimary, size: 22),
      ),
      cardTheme: CardThemeData(
        elevation: 0, color: darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardRadius)),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkAccent, foregroundColor: darkBackground, elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius)),
          textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkTextPrimary,
          side: const BorderSide(color: darkBorder),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: darkSurface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: darkBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: darkBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: darkPrimary, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent, elevation: 0,
        selectedItemColor: darkTextPrimary, unselectedItemColor: darkTextTertiary,
        showSelectedLabels: false, showUnselectedLabels: false,
      ),
    );
  }
}
