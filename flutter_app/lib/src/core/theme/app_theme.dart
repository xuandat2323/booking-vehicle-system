import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_spacing.dart';

/// GoRento design system — open rhythm, calm surfaces, brand-led hierarchy.
class AppTheme {
  AppTheme._();

  static const _primary = Color(0xFF0A2E5C);
  static const _primaryBright = Color(0xFF1B4F8A);
  static const _accent = Color(0xFFC45C26);
  static const _success = Color(0xFF1F6B4A);

  static const _surface = Color(0xFFF5F7FA);
  static const _surfaceLowest = Color(0xFFFFFFFF);
  static const _surfaceLow = Color(0xFFEEF2F6);
  static const _surfaceMid = Color(0xFFE6EBF1);
  static const _surfaceHigh = Color(0xFFDDE3EB);
  static const _surfaceHighest = Color(0xFFD4DBE4);

  static const _onSurface = Color(0xFF12181F);
  static const _onSurfaceVariant = Color(0xFF5A6573);
  static const _outline = Color(0xFF8A94A1);
  static const _outlineVariant = Color(0xFFC5CDD8);

  static BoxShadow get ambientShadow => BoxShadow(
        color: _primary.withValues(alpha: 0.07),
        blurRadius: 28,
        offset: const Offset(0, 12),
      );

  static BoxShadow get softShadow => BoxShadow(
        color: const Color(0xFF12181F).withValues(alpha: 0.05),
        blurRadius: 16,
        offset: const Offset(0, 6),
      );

  static const primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [_primary, _primaryBright],
  );

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF071E3D),
      Color(0xFF0A2E5C),
      Color(0xFF1B4F8A),
    ],
    stops: [0.0, 0.45, 1.0],
  );

  static const pageAtmosphere = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFE8EEF5),
      Color(0xFFF5F7FA),
      Color(0xFFF5F7FA),
    ],
    stops: [0.0, 0.22, 1.0],
  );

  static const double radiusCard = 20;
  static const double radiusInput = 14;
  static const double radiusPill = 999;
  static const double radiusChip = 12;

  static const double spacingXs = AppSpacing.xs;
  static const double spacingSm = AppSpacing.sm;
  static const double spacingMd = AppSpacing.md;
  static const double spacingLg = AppSpacing.lg;
  static const double spacingXl = AppSpacing.xl;

  static ColorScheme get colorScheme => const ColorScheme(
        brightness: Brightness.light,
        primary: _primary,
        onPrimary: Colors.white,
        primaryContainer: _primaryBright,
        onPrimaryContainer: Color(0xFFD6E6FF),
        secondary: _accent,
        onSecondary: Colors.white,
        secondaryContainer: Color(0xFFFFE0D0),
        onSecondaryContainer: Color(0xFF5A2410),
        tertiary: _success,
        onTertiary: Colors.white,
        tertiaryContainer: Color(0xFFC8EEDC),
        onTertiaryContainer: Color(0xFF0C3D28),
        error: Color(0xFFB3261E),
        onError: Colors.white,
        errorContainer: Color(0xFFF9DEDC),
        onErrorContainer: Color(0xFF410E0B),
        surface: _surface,
        onSurface: _onSurface,
        onSurfaceVariant: _onSurfaceVariant,
        outline: _outline,
        outlineVariant: _outlineVariant,
        surfaceContainerLowest: _surfaceLowest,
        surfaceContainerLow: _surfaceLow,
        surfaceContainer: _surfaceMid,
        surfaceContainerHigh: _surfaceHigh,
        surfaceContainerHighest: _surfaceHighest,
        inverseSurface: Color(0xFF2A313A),
        onInverseSurface: Color(0xFFEFF2F6),
        inversePrimary: Color(0xFF9ECAFF),
        shadow: Color(0xFF000000),
        scrim: Color(0xFF000000),
        surfaceTint: _primaryBright,
      );

  static TextTheme get textTheme {
    final display = GoogleFonts.outfitTextTheme();
    final body = GoogleFonts.plusJakartaSansTextTheme();

    return body.copyWith(
      displayLarge: display.displayLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -1.2,
        color: _onSurface,
        height: 1.1,
      ),
      displayMedium: display.displayMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        color: _onSurface,
      ),
      displaySmall: display.displaySmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: _onSurface,
      ),
      headlineLarge: display.headlineLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: _onSurface,
      ),
      headlineMedium: display.headlineMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: _onSurface,
      ),
      headlineSmall: display.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.15,
        color: _onSurface,
      ),
      titleLarge: body.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: _onSurface,
      ),
      titleMedium: body.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: _onSurface,
      ),
      titleSmall: body.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: _onSurface,
      ),
      bodyLarge: body.bodyLarge?.copyWith(color: _onSurface, height: 1.55),
      bodyMedium: body.bodyMedium?.copyWith(color: _onSurfaceVariant, height: 1.5),
      bodySmall: body.bodySmall?.copyWith(color: _onSurfaceVariant, height: 1.45),
      labelLarge: body.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: _onSurface,
      ),
      labelMedium: body.labelMedium?.copyWith(
        fontWeight: FontWeight.w500,
        color: _onSurfaceVariant,
      ),
      labelSmall: body.labelSmall?.copyWith(
        fontWeight: FontWeight.w500,
        color: _onSurfaceVariant,
      ),
    );
  }

  static ThemeData get theme {
    final cs = colorScheme;
    final tt = textTheme;

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      textTheme: tt,
      scaffoldBackgroundColor: cs.surface,
      brightness: Brightness.light,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        centerTitle: false,
        titleTextStyle: tt.titleLarge?.copyWith(fontSize: 20),
        toolbarHeight: 64,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cs.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.55)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(color: cs.primary.withValues(alpha: 0.55), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(color: cs.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(color: cs.error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        labelStyle: tt.bodyMedium,
        hintStyle: tt.bodyMedium?.copyWith(color: cs.outline),
        prefixIconColor: cs.outline,
        suffixIconColor: cs.outline,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusInput),
          ),
          textStyle: tt.labelLarge?.copyWith(fontSize: 15),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.primary,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusInput),
          ),
          side: BorderSide(color: cs.primary.withValues(alpha: 0.28)),
          textStyle: tt.labelLarge?.copyWith(fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cs.primary,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          textStyle: tt.labelLarge?.copyWith(fontSize: 14),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cs.surfaceContainerLow,
        selectedColor: cs.primary.withValues(alpha: 0.12),
        labelStyle: tt.labelMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusChip),
        ),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cs.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
        ),
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: cs.inverseSurface,
        contentTextStyle: tt.bodyMedium?.copyWith(color: cs.onInverseSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusInput),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: cs.outlineVariant.withValues(alpha: 0.35),
        thickness: 1,
        space: AppSpacing.lg,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cs.surfaceContainerLowest,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        showDragHandle: true,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }
}

class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.isLoading = false,
    this.width,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final bool isLoading;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: onPressed != null ? AppTheme.primaryGradient : null,
          color: onPressed == null ? Colors.grey[300] : null,
          borderRadius: BorderRadius.circular(AppTheme.radiusInput),
          boxShadow: onPressed != null ? [AppTheme.softShadow] : null,
        ),
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusInput),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : child,
        ),
      ),
    );
  }
}
