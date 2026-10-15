import 'package:flutter/material.dart';

/// Give & Take design system — "minimal premium".
///
/// One deep brand colour, ink-coloured type on a warm off-white, hairline
/// borders and soft shadows. Screens should take colours, spacing, radii
/// and text styles from here instead of hard-coding them, so the whole app
/// stays consistent and can be re-tuned in one place.
class AppColors {
  AppColors._();

  // Brand
  static const primary = Color(0xFF14877B); // teal, lighter than the old #0B5D57
  static const primaryDark = Color(0xFF0E6A60);
  static const primarySoft = Color(0xFFE4F3F0);
  static const student = Color(0xFF4C3A8F); // muted plum, student market
  static const studentSoft = Color(0xFFEEEBF7);
  static const gold = Color(0xFFB8913F); // ratings / premium accents

  // Neutrals
  static const background = Color(0xFFF6F6F3);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF0F0EC);
  static const ink = Color(0xFF14171A);
  static const inkSecondary = Color(0xFF5E6670);
  static const inkTertiary = Color(0xFF9AA0A8);
  static const hairline = Color(0xFFE6E6E1);

  // Status
  static const success = Color(0xFF1E7F55);
  static const successSoft = Color(0xFFE5F3EC);
  static const danger = Color(0xFFC73A2E);
  static const dangerSoft = Color(0xFFFBEAE8);
  static const warning = Color(0xFFB7791F);
  static const warningSoft = Color(0xFFFBF2E3);
}

class AppSpace {
  AppSpace._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;

  /// Horizontal page padding used by every screen.
  static const page = 20.0;
}

class AppRadius {
  AppRadius._();
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 18.0;
  static const xl = 24.0;
  static const pill = 999.0;
}

class AppShadows {
  AppShadows._();
  static const soft = [
    BoxShadow(color: Color(0x0F14171A), blurRadius: 24, offset: Offset(0, 8)),
  ];
  static const lifted = [
    BoxShadow(color: Color(0x1A14171A), blurRadius: 32, offset: Offset(0, 12)),
  ];

  /// Two-layer shadow (tight contact + wide ambient) so cards read as
  /// sitting slightly above the page rather than being outlined on it.
  static const raised = [
    BoxShadow(color: Color(0x0D14171A), blurRadius: 3, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x1214171A), blurRadius: 18, offset: Offset(0, 8)),
  ];

  /// Coloured glow under a gradient button/FAB.
  static List<BoxShadow> glow(Color color) => [
        BoxShadow(
            color: color.withOpacity(0.32),
            blurRadius: 18,
            offset: const Offset(0, 8)),
      ];
}

/// Gradients that give buttons and banners a soft, convex look: lighter at
/// the top edge, the base colour at the bottom.
class AppGradients {
  AppGradients._();

  static LinearGradient of(Color base) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color.lerp(base, Colors.white, 0.14)!, base],
      );

  static final primary = of(AppColors.primary);

  /// Thin highlight laid over the top half of a gradient surface.
  static const gloss = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.center,
    colors: [Color(0x33FFFFFF), Color(0x00FFFFFF)],
  );
}

class AppText {
  AppText._();
  static const fontFamily = 'IBMPlexSansThai';
  static const display = TextStyle(
      fontSize: 28, fontWeight: FontWeight.w700, height: 1.2,
      letterSpacing: -0.6, color: AppColors.ink);
  static const title = TextStyle(
      fontSize: 20, fontWeight: FontWeight.w700, height: 1.25,
      letterSpacing: -0.3, color: AppColors.ink);
  static const subtitle = TextStyle(
      fontSize: 16, fontWeight: FontWeight.w600, height: 1.3,
      letterSpacing: -0.1, color: AppColors.ink);
  static const body = TextStyle(
      fontSize: 15, fontWeight: FontWeight.w400, height: 1.45,
      color: AppColors.ink);
  static const bodySecondary = TextStyle(
      fontSize: 14, fontWeight: FontWeight.w400, height: 1.45,
      color: AppColors.inkSecondary);
  static const label = TextStyle(
      fontSize: 13, fontWeight: FontWeight.w600, height: 1.3,
      letterSpacing: 0.1, color: AppColors.ink);
  static const caption = TextStyle(
      fontSize: 12, fontWeight: FontWeight.w400, height: 1.35,
      color: AppColors.inkSecondary);
  static const overline = TextStyle(
      fontSize: 11, fontWeight: FontWeight.w600, height: 1.3,
      letterSpacing: 1.2, color: AppColors.inkTertiary);
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      error: AppColors.danger,
    );
    final roundedMd = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md));

    return ThemeData(
      useMaterial3: true,
      fontFamily: AppText.fontFamily,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      splashFactory: InkSparkle.splashFactory,
      dividerColor: AppColors.hairline,
      dividerTheme: const DividerThemeData(
          color: AppColors.hairline, thickness: 1, space: 1),
      textTheme: const TextTheme(
        headlineMedium: AppText.display,
        titleLarge: AppText.title,
        titleMedium: AppText.subtitle,
        bodyLarge: AppText.body,
        bodyMedium: AppText.bodySecondary,
        labelLarge: AppText.label,
        bodySmall: AppText.caption,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        foregroundColor: AppColors.ink,
        iconTheme: IconThemeData(color: AppColors.ink),
        titleTextStyle: AppText.subtitle,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.hairline,
          elevation: 0,
          minimumSize: const Size(0, 52),
          shape: roundedMd,
          textStyle: AppText.subtitle,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.hairline),
          minimumSize: const Size(0, 48),
          shape: roundedMd,
          textStyle: AppText.label,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
            foregroundColor: AppColors.primary, textStyle: AppText.label),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: AppText.bodySecondary.copyWith(color: AppColors.inkTertiary),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.hairline)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.hairline)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.ink, width: 1.2)),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.ink,
        side: const BorderSide(color: AppColors.hairline),
        shape: const StadiumBorder(),
        labelStyle: AppText.label,
        secondaryLabelStyle: AppText.label.copyWith(color: Colors.white),
        showCheckmark: false,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: AppText.body.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
        shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl)),
        titleTextStyle: AppText.title,
        contentTextStyle: AppText.bodySecondary,
      ),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: AppColors.primary),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.ink,
        unselectedLabelColor: AppColors.inkTertiary,
        indicatorColor: AppColors.ink,
        labelStyle: AppText.label,
      ),
    );
  }
}
