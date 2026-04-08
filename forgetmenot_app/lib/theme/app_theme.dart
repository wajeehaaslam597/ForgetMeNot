import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Color Palette ─────────────────────────────────────────────────────────
  static const Color primary        = Color(0xFF5B8DEF);   // Calm blue
  static const Color primaryDark    = Color(0xFF3A6BD4);
  static const Color primaryLight   = Color(0xFFD6E4FF);
  static const Color secondary      = Color(0xFF7EC8A4);   // Soft green
  static const Color secondaryDark  = Color(0xFF4EAB7A);
  static const Color accent         = Color(0xFFFFA468);   // Warm orange
  static const Color danger         = Color(0xFFEF5B5B);
  static const Color warning        = Color(0xFFFFC857);
  static const Color success        = Color(0xFF5CB85C);
  static const Color surface        = Color(0xFFF8F9FF);
  static const Color cardBg         = Color(0xFFFFFFFF);
  static const Color textDark       = Color(0xFF1A1D3A);
  static const Color textMid        = Color(0xFF5A5F7D);
  static const Color textLight      = Color(0xFFA0A5C0);
  static const Color divider        = Color(0xFFE8EAFF);

  static const Color reminderMed    = Color(0xFFEF6B6B);
  static const Color reminderMeal   = Color(0xFFFFA468);
  static const Color reminderAppt   = Color(0xFF5B8DEF);
  static const Color reminderCustom = Color(0xFF9B59B6);

  // ── Gradients ─────────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF5B8DEF), Color(0xFF7EC8A4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient headerGradient = LinearGradient(
    colors: [Color(0xFF3A6BD4), Color(0xFF5B8DEF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF5B8DEF), Color(0xFF8BA7F5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient greenGradient = LinearGradient(
    colors: [Color(0xFF7EC8A4), Color(0xFF4EAB7A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Text Styles ─────────────────────────────────────────────────────────
  static TextTheme get textTheme => TextTheme(
    displayLarge:  GoogleFonts.nunito(fontSize: 32, fontWeight: FontWeight.w800, color: textDark),
    displayMedium: GoogleFonts.nunito(fontSize: 26, fontWeight: FontWeight.w700, color: textDark),
    displaySmall:  GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w700, color: textDark),
    headlineLarge: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w700, color: textDark),
    headlineMedium:GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w600, color: textDark),
    headlineSmall: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w600, color: textDark),
    titleLarge:    GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: textDark),
    titleMedium:   GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600, color: textDark),
    titleSmall:    GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600, color: textMid),
    bodyLarge:     GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w500, color: textDark),
    bodyMedium:    GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w400, color: textMid),
    bodySmall:     GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w400, color: textLight),
    labelLarge:    GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
  );

  // ── Theme Data ─────────────────────────────────────────────────────────
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      primary:   primary,
      secondary: secondary,
      surface:   surface,
      error:     danger,
    ),
    scaffoldBackgroundColor: surface,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: GoogleFonts.nunito(
        fontSize: 20, fontWeight: FontWeight.w700, color: textDark,
      ),
      iconTheme: const IconThemeData(color: textDark),
    ),
    cardTheme: CardThemeData(
      color: cardBg,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      hintStyle: GoogleFonts.nunito(color: textLight, fontSize: 14),
    ),
  );

  // ── Reminder Type Colors ─────────────────────────────────────────────────
  static Color reminderColor(String type) {
    switch (type.toLowerCase()) {
      case 'medication': return reminderMed;
      case 'meal':       return reminderMeal;
      case 'appointment':return reminderAppt;
      default:           return reminderCustom;
    }
  }

  static IconData reminderIcon(String type) {
    switch (type.toLowerCase()) {
      case 'medication':  return Icons.medication_rounded;
      case 'meal':        return Icons.restaurant_rounded;
      case 'appointment': return Icons.calendar_today_rounded;
      default:            return Icons.notifications_rounded;
    }
  }

  // ── Box Shadows ────────────────────────────────────────────────────────
  static List<BoxShadow> get cardShadow => [
    BoxShadow(color: primary.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 6)),
    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
  ];
  static List<BoxShadow> get softShadow => [
    BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4)),
  ];
}