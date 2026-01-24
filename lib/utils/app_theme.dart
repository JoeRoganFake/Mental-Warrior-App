import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Mental Warrior App Theme
/// A premium, minimal design system focused on clarity, motivation, and emotional calm.
/// 
/// Design Philosophy:
/// - Soft gradients with deep neutrals
/// - One confident accent color (Calm Blue)
/// - Strong typography hierarchy
/// - Smooth cards with subtle shadows
/// - Gentle, purposeful animations
/// - Self-discipline, growth, and quiet confidence

class AppTheme {
  // ============================================================================
  // COLORS - Deep neutrals with calm accent
  // ============================================================================
  
  // Primary Background Colors
  static const Color background = Color(0xFF0D0D0F);        // Deep black with slight warmth
  static const Color backgroundSecondary = Color(0xFF141416); // Slightly lighter
  static const Color surface = Color(0xFF1A1A1E);           // Card/surface background
  static const Color surfaceLight = Color(0xFF222228);      // Elevated surface
  static const Color surfaceBorder = Color(0xFF2A2A30);     // Subtle borders
  
  // Accent Colors - Calm Blue palette
  static const Color accent = Color(0xFF4A9EFF);            // Primary accent - Calm Blue
  static const Color accentLight = Color(0xFF6BB3FF);       // Lighter accent
  static const Color accentDark = Color(0xFF3A8EEF);        // Darker accent
  static const Color accentSoft = Color(0xFF4A9EFF);        // For soft backgrounds
  
  // Semantic Colors
  static const Color success = Color(0xFF34C759);           // Growth green
  static const Color successSoft = Color(0xFF2A9D4A);       // Softer green
  static const Color warning = Color(0xFFFFB740);           // Warm amber
  static const Color warningSoft = Color(0xFFE5A435);       // Softer amber
  static const Color error = Color(0xFFFF453A);             // Clear red
  static const Color errorSoft = Color(0xFFD93D33);         // Softer red
  
  // Special Accent Colors for variety
  static const Color purple = Color(0xFF8B5CF6);            // Achievement purple
  static const Color teal = Color(0xFF14B8A6);              // Balance teal
  static const Color orange = Color(0xFFF97316);            // Energy orange
  static const Color pink = Color(0xFFEC4899);              // Motivation pink
  
  // Text Colors
  static const Color textPrimary = Color(0xFFFAFAFA);       // Primary text - almost white
  static const Color textSecondary = Color(0xFFA1A1AA);     // Secondary text - muted
  static const Color textTertiary = Color(0xFF71717A);      // Tertiary text - subtle
  static const Color textDisabled = Color(0xFF52525B);      // Disabled text
  
  // Gradient Definitions
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [background, Color(0xFF0A0A0C)],
  );
  
  static const LinearGradient surfaceGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [surface, Color(0xFF161619)],
  );
  
  static LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentLight, accent],
  );
  
  static LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4ADE80), success],
  );
  
  // ============================================================================
  // TYPOGRAPHY - Strong hierarchy, readable
  // ============================================================================
  
  // Display - Large headers
  static const TextStyle displayLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.5,
    height: 1.2,
  );
  
  static const TextStyle displayMedium = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.3,
    height: 1.2,
  );
  
  static const TextStyle displaySmall = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: -0.2,
    height: 1.3,
  );
  
  // Headlines
  static const TextStyle headlineLarge = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: -0.2,
    height: 1.3,
  );
  
  static const TextStyle headlineMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: -0.1,
    height: 1.3,
  );
  
  static const TextStyle headlineSmall = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    height: 1.4,
  );
  
  // Titles
  static const TextStyle titleLarge = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    height: 1.4,
  );
  
  static const TextStyle titleMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: textPrimary,
    height: 1.4,
  );
  
  static const TextStyle titleSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: 0.1,
    height: 1.4,
  );
  
  // Body
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    height: 1.5,
  );
  
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    height: 1.5,
  );
  
  static const TextStyle bodySmall = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    height: 1.5,
  );
  
  // Labels
  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: textPrimary,
    letterSpacing: 0.1,
    height: 1.4,
  );
  
  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: textSecondary,
    letterSpacing: 0.2,
    height: 1.4,
  );
  
  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: textTertiary,
    letterSpacing: 0.3,
    height: 1.4,
  );
  
  // Special styles
  static const TextStyle buttonText = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    height: 1.2,
  );
  
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textTertiary,
    letterSpacing: 0.2,
    height: 1.4,
  );
  
  // ============================================================================
  // SPACING - Consistent 4px grid
  // ============================================================================
  
  static const double spacing2 = 2;
  static const double spacing4 = 4;
  static const double spacing6 = 6;
  static const double spacing8 = 8;
  static const double spacing10 = 10;
  static const double spacing12 = 12;
  static const double spacing14 = 14;
  static const double spacing16 = 16;
  static const double spacing20 = 20;
  static const double spacing24 = 24;
  static const double spacing28 = 28;
  static const double spacing32 = 32;
  static const double spacing40 = 40;
  static const double spacing48 = 48;
  static const double spacing56 = 56;
  static const double spacing64 = 64;
  
  // Page padding
  static const EdgeInsets pagePadding = EdgeInsets.symmetric(horizontal: 20);
  static const EdgeInsets pagePaddingVertical = EdgeInsets.symmetric(horizontal: 20, vertical: 16);
  
  // ============================================================================
  // BORDER RADIUS - Smooth, rounded components
  // ============================================================================
  
  static const double radiusXs = 6;
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 20;
  static const double radius2Xl = 24;
  static const double radiusFull = 100;
  
  static BorderRadius borderRadiusXs = BorderRadius.circular(radiusXs);
  static BorderRadius borderRadiusSm = BorderRadius.circular(radiusSm);
  static BorderRadius borderRadiusMd = BorderRadius.circular(radiusMd);
  static BorderRadius borderRadiusLg = BorderRadius.circular(radiusLg);
  static BorderRadius borderRadiusXl = BorderRadius.circular(radiusXl);
  static BorderRadius borderRadius2Xl = BorderRadius.circular(radius2Xl);
  static BorderRadius borderRadiusFull = BorderRadius.circular(radiusFull);
  
  // ============================================================================
  // SHADOWS - Subtle, elegant depth
  // ============================================================================
  
  static List<BoxShadow> shadowSm = [
    BoxShadow(
      color: Colors.black.withOpacity(0.15),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];
  
  static List<BoxShadow> shadowMd = [
    BoxShadow(
      color: Colors.black.withOpacity(0.2),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];
  
  static List<BoxShadow> shadowLg = [
    BoxShadow(
      color: Colors.black.withOpacity(0.25),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];
  
  static List<BoxShadow> shadowXl = [
    BoxShadow(
      color: Colors.black.withOpacity(0.3),
      blurRadius: 24,
      offset: const Offset(0, 12),
    ),
  ];
  
  // Glow shadows for accent elements
  static List<BoxShadow> glowAccent = [
    BoxShadow(
      color: accent.withOpacity(0.3),
      blurRadius: 16,
      spreadRadius: 0,
    ),
  ];
  
  static List<BoxShadow> glowSuccess = [
    BoxShadow(
      color: success.withOpacity(0.3),
      blurRadius: 16,
      spreadRadius: 0,
    ),
  ];
  
  // ============================================================================
  // ANIMATION DURATIONS - Gentle and purposeful
  // ============================================================================
  
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationMedium = Duration(milliseconds: 250);
  static const Duration durationSlow = Duration(milliseconds: 350);
  static const Duration durationSlowest = Duration(milliseconds: 500);
  
  static const Curve curveDefault = Curves.easeOutCubic;
  static const Curve curveEmphasized = Curves.easeInOutCubic;
  static const Curve curveDecelerate = Curves.decelerate;
  static const Curve curveElastic = Curves.elasticOut;
  
  // ============================================================================
  // COMPONENT DECORATIONS - Reusable box decorations
  // ============================================================================
  
  // Card decoration
  static BoxDecoration cardDecoration = BoxDecoration(
    color: surface,
    borderRadius: borderRadiusLg,
    border: Border.all(color: surfaceBorder.withOpacity(0.5), width: 1),
  );
  
  // Elevated card decoration
  static BoxDecoration cardElevatedDecoration = BoxDecoration(
    color: surfaceLight,
    borderRadius: borderRadiusLg,
    boxShadow: shadowMd,
  );
  
  // Input field decoration
  static BoxDecoration inputDecoration = BoxDecoration(
    color: surface,
    borderRadius: borderRadiusMd,
    border: Border.all(color: surfaceBorder, width: 1),
  );
  
  // Focused input decoration
  static BoxDecoration inputFocusedDecoration = BoxDecoration(
    color: surface,
    borderRadius: borderRadiusMd,
    border: Border.all(color: accent, width: 1.5),
  );
  
  // Chip/tag decoration
  static BoxDecoration chipDecoration = BoxDecoration(
    color: surfaceLight,
    borderRadius: borderRadiusFull,
    border: Border.all(color: surfaceBorder, width: 1),
  );
  
  // Accent chip decoration
  static BoxDecoration chipAccentDecoration = BoxDecoration(
    color: accent.withOpacity(0.15),
    borderRadius: borderRadiusFull,
    border: Border.all(color: accent.withOpacity(0.3), width: 1),
  );
  
  // ============================================================================
  // THEME DATA - Full Flutter ThemeData
  // ============================================================================
  
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: accent,
      scaffoldBackgroundColor: background,
      canvasColor: surface,
      
      // Color scheme
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: accentLight,
        surface: surface,
        error: error,
        onPrimary: textPrimary,
        onSecondary: textPrimary,
        onSurface: textPrimary,
        onError: textPrimary,
      ),
      
      // AppBar theme
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: headlineMedium,
        iconTheme: IconThemeData(color: textPrimary, size: 24),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: background,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      ),
      
      // Bottom navigation bar
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: accent,
        unselectedItemColor: textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: labelSmall,
        unselectedLabelStyle: labelSmall,
      ),
      
      // Card theme
      cardTheme: CardTheme(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: borderRadiusLg),
        margin: EdgeInsets.zero,
      ),
      
      // Elevated button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: textPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: borderRadiusMd),
          textStyle: buttonText,
        ),
      ),
      
      // Text button theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: borderRadiusSm),
          textStyle: buttonText,
        ),
      ),
      
      // Outlined button theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: surfaceBorder, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: borderRadiusMd),
          textStyle: buttonText,
        ),
      ),
      
      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: borderRadiusMd,
          borderSide: const BorderSide(color: surfaceBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: borderRadiusMd,
          borderSide: const BorderSide(color: surfaceBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: borderRadiusMd,
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: borderRadiusMd,
          borderSide: const BorderSide(color: error, width: 1),
        ),
        hintStyle: bodyMedium.copyWith(color: textTertiary),
        labelStyle: labelMedium,
      ),
      
      // Divider theme
      dividerTheme: const DividerThemeData(
        color: surfaceBorder,
        thickness: 1,
        space: 1,
      ),
      
      // Dialog theme
      dialogTheme: DialogTheme(
        backgroundColor: surface,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: borderRadiusXl),
        titleTextStyle: headlineSmall,
        contentTextStyle: bodyMedium,
      ),
      
      // Bottom sheet theme
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        elevation: 8,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXl)),
        ),
      ),
      
      // Snackbar theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceLight,
        contentTextStyle: bodyMedium.copyWith(color: textPrimary),
        shape: RoundedRectangleBorder(borderRadius: borderRadiusMd),
        behavior: SnackBarBehavior.floating,
      ),
      
      // Progress indicator theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: surfaceBorder,
        circularTrackColor: surfaceBorder,
      ),
      
      // Slider theme
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: surfaceBorder,
        thumbColor: accent,
        overlayColor: accent.withOpacity(0.2),
        trackHeight: 4,
      ),
      
      // Switch theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return textTertiary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent.withOpacity(0.4);
          return surfaceBorder;
        }),
      ),
      
      // Checkbox theme
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(textPrimary),
        side: const BorderSide(color: textTertiary, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      
      // Floating action button theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: textPrimary,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: borderRadiusLg),
      ),
      
      // Tab bar theme
      tabBarTheme: TabBarTheme(
        labelColor: accent,
        unselectedLabelColor: textTertiary,
        labelStyle: titleSmall,
        unselectedLabelStyle: titleSmall.copyWith(fontWeight: FontWeight.w400),
        indicator: UnderlineTabIndicator(
          borderSide: const BorderSide(color: accent, width: 2),
          borderRadius: BorderRadius.circular(1),
        ),
        indicatorSize: TabBarIndicatorSize.label,
      ),
      
      // List tile theme
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: borderRadiusMd),
        titleTextStyle: titleMedium,
        subtitleTextStyle: bodySmall,
        iconColor: textSecondary,
      ),
      
      // Icon theme
      iconTheme: const IconThemeData(
        color: textSecondary,
        size: 24,
      ),
      
      // Text theme
      textTheme: const TextTheme(
        displayLarge: displayLarge,
        displayMedium: displayMedium,
        displaySmall: displaySmall,
        headlineLarge: headlineLarge,
        headlineMedium: headlineMedium,
        headlineSmall: headlineSmall,
        titleLarge: titleLarge,
        titleMedium: titleMedium,
        titleSmall: titleSmall,
        bodyLarge: bodyLarge,
        bodyMedium: bodyMedium,
        bodySmall: bodySmall,
        labelLarge: labelLarge,
        labelMedium: labelMedium,
        labelSmall: labelSmall,
      ),
    );
  }
  
  // ============================================================================
  // HELPER METHODS
  // ============================================================================
  
  /// Sets the system UI overlay style for dark theme
  static void setSystemUIOverlayStyle() {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: background,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
  }
  
  /// Creates a gradient background decoration
  static BoxDecoration gradientBackground({
    List<Color>? colors,
    AlignmentGeometry begin = Alignment.topCenter,
    AlignmentGeometry end = Alignment.bottomCenter,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: begin,
        end: end,
        colors: colors ?? [background, const Color(0xFF0A0A0C)],
      ),
    );
  }
  
  /// Creates a card with optional accent border
  static BoxDecoration accentCard({Color? accentColor, double opacity = 0.3}) {
    final color = accentColor ?? accent;
    return BoxDecoration(
      color: surface,
      borderRadius: borderRadiusLg,
      border: Border.all(color: color.withOpacity(opacity), width: 1),
    );
  }
  
  /// Creates a subtle button decoration
  static BoxDecoration subtleButton({Color? color}) {
    final buttonColor = color ?? accent;
    return BoxDecoration(
      color: buttonColor.withOpacity(0.12),
      borderRadius: borderRadiusMd,
    );
  }
  
  /// Creates a glass-like decoration
  static BoxDecoration glassMorphism({double opacity = 0.1}) {
    return BoxDecoration(
      color: Colors.white.withOpacity(opacity),
      borderRadius: borderRadiusLg,
      border: Border.all(
        color: Colors.white.withOpacity(0.1),
        width: 1,
      ),
    );
  }
}

// ============================================================================
// CUSTOM WIDGETS - Reusable themed components
// ============================================================================

/// A themed card with consistent styling
class ThemedCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final bool elevated;

  const ThemedCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppTheme.surface,
        borderRadius: AppTheme.borderRadiusLg,
        border: Border.all(
          color: borderColor ?? AppTheme.surfaceBorder.withOpacity(0.5),
          width: 1,
        ),
        boxShadow: elevated ? AppTheme.shadowMd : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppTheme.borderRadiusLg,
          child: Padding(
            padding: padding ?? const EdgeInsets.all(AppTheme.spacing16),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A themed section header
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.titleLarge),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: AppTheme.bodySmall),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// A themed primary button
class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expanded;
  final Color? backgroundColor;

  const PrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.expanded = true,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final button = Container(
      height: 52,
      decoration: BoxDecoration(
        gradient: backgroundColor == null ? AppTheme.accentGradient : null,
        color: backgroundColor,
        borderRadius: AppTheme.borderRadiusMd,
        boxShadow: AppTheme.glowAccent,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: loading ? null : onPressed,
          borderRadius: AppTheme.borderRadiusMd,
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.textPrimary,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 20, color: AppTheme.textPrimary),
                        const SizedBox(width: 8),
                      ],
                      Text(text, style: AppTheme.buttonText.copyWith(color: AppTheme.textPrimary)),
                    ],
                  ),
          ),
        ),
      ),
    );

    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// A themed secondary/outline button
class SecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expanded;

  const SecondaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.expanded = true,
  });

  @override
  Widget build(BuildContext context) {
    final button = Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: AppTheme.borderRadiusMd,
        border: Border.all(color: AppTheme.surfaceBorder, width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: AppTheme.borderRadiusMd,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: AppTheme.textPrimary),
                  const SizedBox(width: 8),
                ],
                Text(text, style: AppTheme.buttonText.copyWith(color: AppTheme.textPrimary)),
              ],
            ),
          ),
        ),
      ),
    );

    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// A themed input field
class ThemedTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final String? labelText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Function(String)? onChanged;
  final String? Function(String?)? validator;
  final int maxLines;
  final bool readOnly;
  final VoidCallback? onTap;

  const ThemedTextField({
    super.key,
    this.controller,
    this.hintText,
    this.labelText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.onChanged,
    this.validator,
    this.maxLines = 1,
    this.readOnly = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (labelText != null) ...[
          Text(labelText!, style: AppTheme.labelMedium),
          const SizedBox(height: 8),
        ],
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          onChanged: onChanged,
          validator: validator,
          maxLines: maxLines,
          readOnly: readOnly,
          onTap: onTap,
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
          cursorColor: AppTheme.accent,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, color: AppTheme.textTertiary, size: 20)
                : null,
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}

/// A themed chip/tag
class ThemedChip extends StatelessWidget {
  final String label;
  final Color? color;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  const ThemedChip({
    super.key,
    required this.label,
    this.color,
    this.selected = false,
    this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppTheme.accent;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppTheme.durationFast,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? chipColor.withOpacity(0.2) : AppTheme.surfaceLight,
          borderRadius: AppTheme.borderRadiusFull,
          border: Border.all(
            color: selected ? chipColor.withOpacity(0.5) : AppTheme.surfaceBorder,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: selected ? chipColor : AppTheme.textSecondary),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: AppTheme.labelMedium.copyWith(
                color: selected ? chipColor : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A themed stat card for displaying metrics
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color? accentColor;
  final String? subtitle;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.accentColor,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppTheme.accent;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: AppTheme.borderRadiusLg,
        border: Border.all(color: AppTheme.surfaceBorder.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: AppTheme.borderRadiusSm,
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  label,
                  style: AppTheme.labelMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: AppTheme.headlineMedium),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: AppTheme.caption),
          ],
        ],
      ),
    );
  }
}
