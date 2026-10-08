import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Aetherix design tokens — dark cybersecurity command center.
class AppColors {
  AppColors._();

  // Surfaces
  static const bgPrimary = Color(0xFF141414);
  static const bgSecondary = Color(0xFF1A1A1A);
  static const surface = Color(0xFF202020);
  static const surfaceElevated = Color(0xFF252525);
  static const border = Color(0xFF303030);

  // Lime accent
  static const lime = Color(0xFF9FEF00);
  static const limeHover = Color(0xFFB6FF33);
  static const limeDim = Color(0xFF7FBF00);
  static const limeInk = Color(0xFF1A1A1A); // text-on-lime

  // Text
  static const textPrimary = Color(0xFFF2F2F2);
  static const textSecondary = Color(0xFFB3B3B3);
  static const textMuted = Color(0xFF777777);
  static const textDisabled = Color(0xFF555555);

  // Semantic (used sparingly)
  static const critical = Color(0xFFE53935);
  static const warning = Color(0xFFFFB300);
  static const info = Color(0xFF6FA8DC);
}

/// Spacing scale — use these everywhere for rhythm.
class AppSpacing {
  AppSpacing._();
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 28.0;
  static const xxl = 40.0;
}

class AppRadii {
  AppRadii._();
  static const sharp = 2.0;
  static const small = 4.0;
  static const medium = 6.0;
}

class AppTheme {
  AppTheme._();

  /// Single dark theme — this is a cybersecurity intelligence platform,
  /// not a consumer app. There is no light theme.
  static ThemeData get dark {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bgPrimary,
      canvasColor: AppColors.bgPrimary,
      dividerColor: AppColors.border,
      splashColor: AppColors.lime.withValues(alpha: 0.06),
      highlightColor: AppColors.lime.withValues(alpha: 0.04),
    );

    // Inter for primary, JetBrains Mono for technical.
    final inter = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );
    final mono = GoogleFonts.jetBrainsMonoTextTheme(base.textTheme);

    final textTheme = inter.copyWith(
      // Headings: bold, compact, slightly tight.
      displayLarge: inter.displayLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: AppColors.textPrimary,
      ),
      headlineLarge: inter.headlineLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: AppColors.textPrimary,
      ),
      headlineMedium: inter.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: AppColors.textPrimary,
      ),
      headlineSmall: inter.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: AppColors.textPrimary,
      ),
      titleLarge: inter.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      titleMedium: inter.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      titleSmall: inter.titleSmall?.copyWith(
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
        letterSpacing: 0.6,
      ),
      bodyLarge: inter.bodyLarge?.copyWith(color: AppColors.textPrimary),
      bodyMedium: inter.bodyMedium?.copyWith(color: AppColors.textSecondary),
      bodySmall: inter.bodySmall?.copyWith(color: AppColors.textMuted),
      labelLarge: inter.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
      ),
      labelMedium: inter.labelMedium?.copyWith(color: AppColors.textMuted),
      labelSmall: mono.labelSmall?.copyWith(
        color: AppColors.textMuted,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w500,
      ),
    );

    return base.copyWith(
      textTheme: textTheme,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.lime,
        onPrimary: AppColors.limeInk,
        secondary: AppColors.limeDim,
        onSecondary: AppColors.limeInk,
        surface: AppColors.bgSecondary,
        onSurface: AppColors.textPrimary,
        surfaceContainerHighest: AppColors.surfaceElevated,
        outline: AppColors.border,
        error: AppColors.critical,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bgPrimary,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleMedium?.copyWith(
          color: AppColors.textPrimary,
          letterSpacing: 1.0,
          fontWeight: FontWeight.w700,
        ),
        toolbarHeight: 56,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.small),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        space: 1,
        thickness: 1,
      ),
      iconTheme: const IconThemeData(color: AppColors.textSecondary, size: 20),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.bgSecondary,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.lime.withValues(alpha: 0.18),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.lime, size: 22);
          }
          return const IconThemeData(color: AppColors.textMuted, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final color = states.contains(WidgetState.selected)
              ? AppColors.lime
              : AppColors.textMuted;
          return textTheme.labelSmall?.copyWith(color: color, letterSpacing: 0.6);
        }),
        height: 64,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 2,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.small),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.small),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.small),
          borderSide: const BorderSide(color: AppColors.lime, width: 1.4),
        ),
        prefixIconColor: AppColors.textMuted,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.lime,
          foregroundColor: AppColors.limeInk,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm + 2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.small),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.lime,
          side: const BorderSide(color: AppColors.lime, width: 1.2),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm + 2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.small),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.lime,
          textStyle: textTheme.labelLarge?.copyWith(letterSpacing: 0.6),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        side: const BorderSide(color: AppColors.border),
        labelStyle: textTheme.labelSmall?.copyWith(
          color: AppColors.textSecondary,
          letterSpacing: 0.6,
        ),
        selectedColor: AppColors.lime.withValues(alpha: 0.16),
        secondarySelectedColor: AppColors.lime.withValues(alpha: 0.16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.small),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        showCheckmark: false,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceElevated,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.textPrimary,
        ),
        actionTextColor: AppColors.lime,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.small),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.lime,
        linearTrackColor: AppColors.surface,
      ),
    );
  }
}

/// Semantic helpers for content (Importance → label + color).
enum ImportanceTier {
  critical(label: 'CRITICAL', color: AppColors.critical),
  high(label: 'HIGH', color: AppColors.warning),
  medium(label: 'MEDIUM', color: AppColors.limeDim),
  low(label: 'LOW', color: AppColors.textMuted);

  const ImportanceTier({required this.label, required this.color});
  final String label;
  final Color color;

  static ImportanceTier fromScore(double? score) {
    final s = score ?? 0;
    if (s >= 9) return ImportanceTier.critical;
    if (s >= 7) return ImportanceTier.high;
    if (s >= 4) return ImportanceTier.medium;
    return ImportanceTier.low;
  }
}

/// Reusable monospace text widget for technical metadata.
class MonoText extends StatelessWidget {
  const MonoText(
    this.text, {
    super.key,
    this.size = 11,
    this.color = AppColors.textMuted,
    this.weight = FontWeight.w500,
    this.letterSpacing = 0.8,
  });
  final String text;
  final double size;
  final Color color;
  final FontWeight weight;
  final double letterSpacing;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.jetBrainsMono(
        fontSize: size,
        color: color,
        fontWeight: weight,
        letterSpacing: letterSpacing,
      ),
    );
  }
}

/// A small status pill with a lime dot and uppercase label.
class StatusDot extends StatelessWidget {
  const StatusDot(this.label, {super.key, this.color = AppColors.lime});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.6),
                blurRadius: 6,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        MonoText(label, color: color, size: 10),
      ],
    );
  }
}