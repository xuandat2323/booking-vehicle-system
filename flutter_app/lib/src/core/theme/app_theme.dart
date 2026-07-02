import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// GoRento Design System — "The Editorial Motion System"
/// Extracted from Google Stitch "Giao diện Ứng dụng Thuê xe AutoRent"
class AppTheme {
  AppTheme._();

  // ─── Brand Colors ───
  static const _primaryValue = Color(0xFF002653);
  static const _primaryContainer = Color(0xFF1A3C6E);
  static const _secondaryValue = Color(0xFFA83900);
  static const _secondaryContainer = Color(0xFFFE6A2B);
  static const _tertiaryValue = Color(0xFF002E06);
  static const _tertiaryContainer = Color(0xFF00470E);

  // ─── Surface Hierarchy ───
  static const _surface = Color(0xFFF8F9FA);
  static const _surfaceContainerLowest = Color(0xFFFFFFFF);
  static const _surfaceContainerLow = Color(0xFFF3F4F5);
  static const _surfaceContainer = Color(0xFFEDEEEF);
  static const _surfaceContainerHigh = Color(0xFFE7E8E9);
  static const _surfaceContainerHighest = Color(0xFFE1E3E4);

  // ─── On/Outline Colors ───
  static const _onSurface = Color(0xFF191C1D);
  static const _onSurfaceVariant = Color(0xFF43474F);
  static const _outline = Color(0xFF747780);
  static const _outlineVariant = Color(0xFFC4C6D0);

  // ─── Ambient Shadow (primary-tinted) ───
  static BoxShadow get ambientShadow => const BoxShadow(
        color: Color(0x0F1A3C6E),
        blurRadius: 32,
        offset: Offset(0, 12),
      );

  static BoxShadow get softShadow => const BoxShadow(
        color: Color(0x0A1A3C6E),
        blurRadius: 16,
        offset: Offset(0, 4),
      );

  // ─── Gradient for CTAs ───
  static const primaryGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [_primaryValue, _primaryContainer],
  );

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [_primaryValue, _primaryContainer],
  );

  // ─── Corner Radii ───
  static const double radiusCard = 16;
  static const double radiusInput = 12;
  static const double radiusPill = 9999;
  static const double radiusChip = 9999;

  // ─── Spacing ───
  static const double spacingSm = 8;
  static const double spacingMd = 16;
  static const double spacingLg = 24;
  static const double spacingXl = 32;

  // ─── ColorScheme ───
  static ColorScheme get colorScheme => const ColorScheme(
        brightness: Brightness.light,
        primary: _primaryValue,
        onPrimary: Colors.white,
        primaryContainer: _primaryContainer,
        onPrimaryContainer: Color(0xFFD7E3FF),
        secondary: _secondaryValue,
        onSecondary: Colors.white,
        secondaryContainer: _secondaryContainer,
        onSecondaryContainer: Colors.white,
        tertiary: _tertiaryValue,
        onTertiary: Colors.white,
        tertiaryContainer: _tertiaryContainer,
        onTertiaryContainer: Color(0xFFA3F69C),
        error: Color(0xFFBA1A1A),
        onError: Colors.white,
        errorContainer: Color(0xFFFFDAD6),
        onErrorContainer: Color(0xFF93000A),
        surface: _surface,
        onSurface: _onSurface,
        onSurfaceVariant: _onSurfaceVariant,
        outline: _outline,
        outlineVariant: _outlineVariant,
        surfaceContainerLowest: _surfaceContainerLowest,
        surfaceContainerLow: _surfaceContainerLow,
        surfaceContainer: _surfaceContainer,
        surfaceContainerHigh: _surfaceContainerHigh,
        surfaceContainerHighest: _surfaceContainerHighest,
        inverseSurface: Color(0xFF2E3132),
        onInverseSurface: Color(0xFFF0F1F2),
        inversePrimary: Color(0xFFABC7FF),
        shadow: Color(0xFF000000),
        scrim: Color(0xFF000000),
        surfaceTint: Color(0xFF405E92),
      );

  // ─── TextTheme (Be Vietnam Pro) ───
  static TextTheme get _baseTextTheme => GoogleFonts.beVietnamProTextTheme();

  static TextTheme get textTheme {
    final base = _baseTextTheme;
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: _onSurface,
      ),
      displayMedium: base.displayMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: _onSurface,
      ),
      displaySmall: base.displaySmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: _onSurface,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: _onSurface,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: _onSurface,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: _onSurface,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: _onSurface,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: _onSurface,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: _onSurface,
      ),
      bodyLarge: base.bodyLarge?.copyWith(color: _onSurface),
      bodyMedium: base.bodyMedium?.copyWith(color: _onSurfaceVariant),
      bodySmall: base.bodySmall?.copyWith(color: _onSurfaceVariant),
      labelLarge: base.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: _onSurface,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontWeight: FontWeight.w500,
        color: _onSurfaceVariant,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontWeight: FontWeight.w500,
        color: _onSurfaceVariant,
      ),
    );
  }

  // ─── ThemeData ───
  static ThemeData get theme {
    final cs = colorScheme;
    final tt = textTheme;

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      textTheme: tt,
      scaffoldBackgroundColor: cs.surface,
      brightness: Brightness.light,

      // ─── AppBar ───
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        centerTitle: false,
        titleTextStyle: tt.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: cs.onSurface,
        ),
      ),

      // ─── Card (Tonal Layering, no border) ───
      cardTheme: CardThemeData(
        elevation: 0,
        color: cs.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
        ),
        margin: EdgeInsets.zero,
      ),

      // ─── Input Fields (Filled, no border) ───
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(
            color: cs.primary.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(color: cs.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(color: cs.error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: tt.bodyMedium,
        hintStyle: tt.bodyMedium?.copyWith(color: cs.outline),
        prefixIconColor: cs.outline,
        suffixIconColor: cs.outline,
      ),

      // ─── Filled Button (Pill shape, gradient-like) ───
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusPill),
          ),
          textStyle: tt.labelLarge?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          elevation: 0,
        ),
      ),

      // ─── Outlined Button ───
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.primary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusPill),
          ),
          side: BorderSide(color: cs.primary.withValues(alpha: 0.3)),
          textStyle: tt.labelLarge?.copyWith(fontSize: 15),
        ),
      ),

      // ─── Text Button ───
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cs.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusPill),
          ),
          textStyle: tt.labelLarge?.copyWith(fontSize: 14),
        ),
      ),

      // ─── Chip (Pill) ───
      chipTheme: ChipThemeData(
        backgroundColor: cs.surfaceContainerLow,
        selectedColor: cs.primaryContainer.withValues(alpha: 0.15),
        labelStyle: tt.labelMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusChip),
        ),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      // ─── Dialog ───
      dialogTheme: DialogThemeData(
        backgroundColor: cs.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard * 1.5),
        ),
        elevation: 0,
      ),

      // ─── SnackBar ───
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: cs.inverseSurface,
        contentTextStyle: tt.bodyMedium?.copyWith(color: cs.onInverseSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusInput),
        ),
      ),

      // ─── Divider ───
      dividerTheme: DividerThemeData(
        color: cs.outlineVariant.withValues(alpha: 0.15),
        thickness: 1,
        space: 1,
      ),

      // ─── Bottom Sheet ───
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cs.surfaceContainerLowest,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }
}

/// Gradient Button Widget for primary CTAs
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
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          boxShadow: onPressed != null
              ? [AppTheme.softShadow]
              : null,
        ),
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : child,
        ),
      ),
    );
  }
}
