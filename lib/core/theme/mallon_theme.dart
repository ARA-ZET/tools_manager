import 'package:flutter/material.dart';

/// Mallon color palette - white background, black text, green accents
class MallonColors {
  // Base colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color darkGrey = Color(0xFF2C2C2C);
  static const Color mediumGrey = Color(0xFF6C6C6C);
  static const Color lightGrey = Color(0xFFF5F5F5);

  // Green accent variations
  static const Color primaryGreen = Color(
    0xFF2E7D32,
  ); // Dark green for primary actions
  static const Color accentGreen = Color(
    0xFF4CAF50,
  ); // Medium green for highlights
  static const Color lightGreen = Color(
    0xFFE8F5E8,
  ); // Light green for backgrounds
  static const Color successGreen = Color(0xFF66BB6A); // Success states

  // Status colors
  static const Color available = Color(0xFF4CAF50); // Available tools
  static const Color checkedOut = Color(0xFFFF9800); // Checked out tools
  static const Color error = Color(0xFFD32F2F); // Error states
  static const Color warning = Color(0xFFFF9800); // Warning states

  // Text colors
  static const Color primaryText = black;
  static const Color secondaryText = mediumGrey;
  static const Color disabledText = Color(0xFFBDBDBD);

  // Surface colors
  static const Color surface = white;
  static const Color surfaceVariant = lightGrey;
  static const Color outline = Color(0xFFE0E0E0);
}

/// Custom Mallon theme configuration
class MallonTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,

      // Color scheme
      colorScheme: const ColorScheme.light(
        primary: MallonColors.primaryGreen,
        onPrimary: MallonColors.white,
        secondary: MallonColors.accentGreen,
        onSecondary: MallonColors.white,
        surface: MallonColors.surface,
        onSurface: MallonColors.primaryText,
        error: MallonColors.error,
        onError: MallonColors.white,
        outline: MallonColors.outline,
      ),

      // Scaffold
      scaffoldBackgroundColor: MallonColors.white,

      // AppBar theme
      appBarTheme: const AppBarTheme(
        backgroundColor: MallonColors.white,
        foregroundColor: MallonColors.black,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: MallonColors.black,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: MallonColors.black),
      ),

      // Card theme
      cardTheme: CardThemeData(
        color: MallonColors.white,
        elevation: 2,
        shadowColor: MallonColors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: MallonColors.outline, width: 1),
        ),
      ),

      // Elevated button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: MallonColors.primaryGreen,
          foregroundColor: MallonColors.white,
          elevation: 2,
          shadowColor: MallonColors.black.withOpacity(0.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),

      // Outlined button theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: MallonColors.primaryGreen,
          side: const BorderSide(color: MallonColors.primaryGreen, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),

      // Text button theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: MallonColors.primaryGreen,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),

      // Floating action button theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: MallonColors.primaryGreen,
        foregroundColor: MallonColors.white,
        elevation: 4,
      ),

      // Chip theme
      chipTheme: ChipThemeData(
        backgroundColor: MallonColors.lightGreen,
        deleteIconColor: MallonColors.primaryGreen,
        disabledColor: MallonColors.lightGrey,
        selectedColor: MallonColors.accentGreen,
        secondarySelectedColor: MallonColors.lightGreen,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        labelStyle: const TextStyle(
          color: MallonColors.primaryGreen,
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: const TextStyle(
          color: MallonColors.white,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: MallonColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: MallonColors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: MallonColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: MallonColors.primaryGreen,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: MallonColors.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        labelStyle: const TextStyle(color: MallonColors.secondaryText),
        hintStyle: const TextStyle(color: MallonColors.disabledText),
      ),

      // List tile theme
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        titleTextStyle: TextStyle(
          color: MallonColors.primaryText,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        subtitleTextStyle: TextStyle(
          color: MallonColors.secondaryText,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),

      // Bottom navigation bar theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: MallonColors.white,
        selectedItemColor: MallonColors.primaryGreen,
        unselectedItemColor: MallonColors.mediumGrey,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // Switch theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>((
          Set<WidgetState> states,
        ) {
          if (states.contains(WidgetState.selected)) {
            return MallonColors.primaryGreen;
          }
          return MallonColors.mediumGrey;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color>((
          Set<WidgetState> states,
        ) {
          if (states.contains(WidgetState.selected)) {
            return MallonColors.lightGreen;
          }
          return MallonColors.lightGrey;
        }),
      ),

      // Progress indicator theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: MallonColors.primaryGreen,
        linearTrackColor: MallonColors.lightGreen,
        circularTrackColor: MallonColors.lightGreen,
      ),

      // Text theme
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: MallonColors.primaryText,
          fontSize: 32,
          fontWeight: FontWeight.w700,
        ),
        displayMedium: TextStyle(
          color: MallonColors.primaryText,
          fontSize: 28,
          fontWeight: FontWeight.w600,
        ),
        displaySmall: TextStyle(
          color: MallonColors.primaryText,
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
        headlineLarge: TextStyle(
          color: MallonColors.primaryText,
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
        headlineMedium: TextStyle(
          color: MallonColors.primaryText,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        headlineSmall: TextStyle(
          color: MallonColors.primaryText,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          color: MallonColors.primaryText,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: MallonColors.primaryText,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        titleSmall: TextStyle(
          color: MallonColors.primaryText,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(
          color: MallonColors.primaryText,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: TextStyle(
          color: MallonColors.primaryText,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        bodySmall: TextStyle(
          color: MallonColors.secondaryText,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        labelLarge: TextStyle(
          color: MallonColors.primaryText,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        labelMedium: TextStyle(
          color: MallonColors.secondaryText,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        labelSmall: TextStyle(
          color: MallonColors.secondaryText,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Custom widgets and helpers for consistent styling
class MallonWidgets {
  /// Status chip showing tool availability
  static Widget statusChip({required String status, bool isSmall = false}) {
    Color color;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'available':
        color = MallonColors.available;
        icon = Icons.check_circle;
        break;
      case 'checked_out':
      case 'checked out':
        color = MallonColors.checkedOut;
        icon = Icons.access_time;
        break;
      default:
        color = MallonColors.mediumGrey;
        icon = Icons.help_outline;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 8 : 12,
        vertical: isSmall ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(isSmall ? 12 : 16),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isSmall ? 14 : 16, color: color),
          SizedBox(width: isSmall ? 4 : 6),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: isSmall ? 10 : 12,
            ),
          ),
        ],
      ),
    );
  }

  /// Action button with consistent styling
  static Widget actionButton({
    required String label,
    required VoidCallback onPressed,
    required IconData icon,
    bool isPrimary = true,
    bool isDestructive = false,
  }) {
    final color = isDestructive
        ? MallonColors.error
        : isPrimary
        ? MallonColors.primaryGreen
        : MallonColors.mediumGrey;

    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: MallonColors.white,
      ),
    );
  }

  /// Large scan button for scanner screen
  static Widget scanButton({
    required String label,
    required VoidCallback onPressed,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      height: 64,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 28),
        label: Text(
          label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: MallonColors.primaryGreen,
          foregroundColor: MallonColors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
