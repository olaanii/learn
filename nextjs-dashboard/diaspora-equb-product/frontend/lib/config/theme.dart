import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Modern Ethiopian Heritage — Light Mode ──

  static const Color backgroundLight = Color(0xFFF1FAEE); // Warm Cream
  static const Color backgroundDark =
      Color(0xFFE4F0E0); // Slightly deeper cream (gradient end)
  static const Color accentYellow = Color(0xFFD4AF37); // Ethiopian Gold
  static const Color accentYellowDark =
      Color(0xFFF2C94C); // Soft Gold (dark mode accent)
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color darkButton =
      Color(0xFF1B4332); // Deep Forest (light mode button)

  static const Color textPrimary = Color(0xFF081C15); // Dark Forest
  static const Color textSecondary = Color(0xFF4A6354); // Muted Forest
  static const Color textTertiary = Color(0xFF7A9484); // Light Forest
  static const Color textHint = Color(0xFFB5CCBE); // Warm hint

  static const Color positive = Color(0xFF40916C); // Emerald Bright
  static const Color negative = Color(0xFF9B2226); // Deep Red (heritage)
  static const Color warningColor = Color(0xFFD4AF37); // Ethiopian Gold

  static const Color primaryColor = Color(0xFF1B4332); // Deep Forest
  static const Color secondaryColor = Color(0xFF2D6A4F); // Emerald
  static const Color successColor = positive;
  static const Color dangerColor = negative;
  static const Color highlightRed =
      Color(0xFF9B2226); // Heritage accent for alerts

  // ── Modern Ethiopian Heritage — Dark Mode ──

  static const Color darkBackground = Color(0xFF081C15); // Deep Forest Dark
  static const Color _darkBackgroundEnd =
      Color(0xFF051210); // Deeper gradient end
  static const Color darkCard = Color(0xFF0F2E24); // Soft Dark Green
  static const Color darkSurface = Color(0xFF153228); // Dark green surface
  static const Color darkTextPrimary = Color(0xFFE9F5EC); // Soft Light
  static const Color darkTextSecondary = Color(0xFF8DB89A); // Muted light
  static const Color darkTextTertiary = Color(0xFF5A7A66); // Dim green
  static const Color darkBorder = Color(0xFF1C3D2E); // Dark border

  // Dark mode primary/secondary (brighter variants for contrast)
  static const Color darkPrimary = Color(0xFF40916C); // Bright Emerald
  static const Color darkSecondary = Color(0xFF52B788); // Light Emerald
  static const Color darkAccent = Color(0xFFF2C94C); // Soft Gold
  static const Color darkHighlight = Color(0xFFC44536); // Warm Red

  static const double cardRadius = 24.0;
  static const double cardRadiusSmall = 16.0;
  static const double buttonRadius = 28.0;
  static const double wideBreakpoint = 840.0;
  static const double desktopBreakpoint = 1200.0;
  static const double desktopSidebarWidth = 268.0;
  static const double desktopRailWidth = 88.0;
  static const double desktopContentMaxWidth = 1440.0;
  static const double desktopPageGutter = 28.0;
  static const double desktopSectionGap = 24.0;
  static const double desktopPanelGap = 20.0;

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

  static bool isWide(BuildContext context) =>
      MediaQuery.of(context).size.width >= wideBreakpoint;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= desktopBreakpoint;

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
      _isDark(context) ? darkBackground : Colors.white;

  static LinearGradient bgGradient(BuildContext context) =>
      _isDark(context) ? darkBackgroundGradient : backgroundGradient;

  static List<BoxShadow> cardShadowFor(BuildContext context) =>
      _isDark(context) ? const [] : cardShadow;

  static List<BoxShadow> subtleShadowFor(BuildContext context) =>
      _isDark(context) ? const [] : subtleShadow;

  static EdgeInsets pagePaddingFor(BuildContext context) {
    if (isDesktop(context)) {
      return const EdgeInsets.fromLTRB(
        desktopPageGutter,
        24,
        desktopPageGutter,
        32,
      );
    }
    if (isWide(context)) {
      return const EdgeInsets.fromLTRB(20, 16, 20, 24);
    }
    return const EdgeInsets.fromLTRB(20, 12, 20, 24);
  }

  static double contentMaxWidthFor(BuildContext context) =>
      isDesktop(context) ? desktopContentMaxWidth : double.infinity;

  static Border borderFor(BuildContext context, {double opacity = 0.08}) {
    return Border.all(
      color: textPrimaryColor(context).withValues(alpha: opacity),
    );
  }

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
        displayLarge: GoogleFonts.inter(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            color: textPrimary,
            letterSpacing: -0.5),
        displayMedium: GoogleFonts.inter(
            fontSize: 30, fontWeight: FontWeight.w700, color: textPrimary),
        headlineLarge: GoogleFonts.inter(
            fontSize: 24, fontWeight: FontWeight.w700, color: textPrimary),
        headlineMedium: GoogleFonts.inter(
            fontSize: 20, fontWeight: FontWeight.w600, color: textPrimary),
        titleLarge: GoogleFonts.inter(
            fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary),
        titleMedium: GoogleFonts.inter(
            fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary),
        bodyLarge: GoogleFonts.inter(
            fontSize: 16, fontWeight: FontWeight.w400, color: textPrimary),
        bodyMedium: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w400, color: textSecondary),
        bodySmall: GoogleFonts.inter(
            fontSize: 12, fontWeight: FontWeight.w400, color: textTertiary),
        labelLarge: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
            fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary),
        iconTheme: const IconThemeData(color: textPrimary, size: 22),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cardWhite,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(cardRadius)),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkButton,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(buttonRadius)),
          textStyle:
              GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: textHint),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(buttonRadius)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardWhite,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: textHint)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: textHint)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: secondaryColor, width: 2)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: textPrimary,
        unselectedItemColor: textTertiary,
        showSelectedLabels: false,
        showUnselectedLabels: false,
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
        displayLarge: GoogleFonts.inter(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            color: darkTextPrimary,
            letterSpacing: -0.5),
        displayMedium: GoogleFonts.inter(
            fontSize: 30, fontWeight: FontWeight.w700, color: darkTextPrimary),
        headlineLarge: GoogleFonts.inter(
            fontSize: 24, fontWeight: FontWeight.w700, color: darkTextPrimary),
        headlineMedium: GoogleFonts.inter(
            fontSize: 20, fontWeight: FontWeight.w600, color: darkTextPrimary),
        titleLarge: GoogleFonts.inter(
            fontSize: 18, fontWeight: FontWeight.w600, color: darkTextPrimary),
        titleMedium: GoogleFonts.inter(
            fontSize: 16, fontWeight: FontWeight.w600, color: darkTextPrimary),
        bodyLarge: GoogleFonts.inter(
            fontSize: 16, fontWeight: FontWeight.w400, color: darkTextPrimary),
        bodyMedium: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: darkTextSecondary),
        bodySmall: GoogleFonts.inter(
            fontSize: 12, fontWeight: FontWeight.w400, color: darkTextTertiary),
        labelLarge: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w600, color: darkTextPrimary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: darkTextPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
            fontSize: 18, fontWeight: FontWeight.w600, color: darkTextPrimary),
        iconTheme: const IconThemeData(color: darkTextPrimary, size: 22),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: darkCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(cardRadius)),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkAccent,
          foregroundColor: darkBackground,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(buttonRadius)),
          textStyle:
              GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkTextPrimary,
          side: const BorderSide(color: darkBorder),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(buttonRadius)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: darkBorder)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: darkBorder)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: darkPrimary, width: 2)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: darkTextPrimary,
        unselectedItemColor: darkTextTertiary,
        showSelectedLabels: false,
        showUnselectedLabels: false,
      ),
    );
  }
}
