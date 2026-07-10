import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WorkableDesign {
  static const Color ink = Color(0xFF111827);
  static const Color muted = Color(0xFF6B7280);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color canvas = Color(0xFFF6F7F9);
  static const Color border = Color(0xFFE5E7EB);
  static const Color primary = Color(0xFF245BFF);
  static const Color primaryDark = Color(0xFF1D4ED8);
  static const Color accent = Color(0xFF0F766E);
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFDC2626);

  static const double radius = 8;
  static const double pagePadding = 16;

  static ThemeData lightTheme({required bool highContrast}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: highContrast ? Colors.black : primary,
      contrastLevel: highContrast ? 1.0 : 0.0,
    );

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: highContrast ? Colors.white : canvas,
      appBarTheme: AppBarTheme(
        backgroundColor: highContrast ? Colors.black : surface,
        foregroundColor: highContrast ? Colors.white : ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          color: ink,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: highContrast ? Colors.black : primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: highContrast ? Colors.black : primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: highContrast ? Colors.black : primaryDark,
          minimumSize: const Size(48, 48),
          side: BorderSide(color: highContrast ? Colors.black : border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: _inputBorder(border),
        enabledBorder: _inputBorder(border),
        focusedBorder: _inputBorder(highContrast ? Colors.black : primary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: const BorderSide(color: border),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }

  static ThemeData darkTheme({required bool highContrast}) {
    final bg = highContrast ? Colors.black : const Color(0xFF0B1220);
    final card = highContrast ? Colors.black : const Color(0xFF111827);

    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: highContrast ? Colors.white : primary,
        brightness: Brightness.dark,
        contrastLevel: highContrast ? 1.0 : 0.0,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: bg,
      appBarTheme: AppBarTheme(
        backgroundColor: card,
        foregroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }

  static BoxDecoration cardDecoration({
    Color color = surface,
    Color borderColor = border,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor),
    );
  }

  static OutlineInputBorder _inputBorder(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide(color: color),
    );
  }
}
