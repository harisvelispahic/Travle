import 'package:flutter/material.dart';

import 'tokens.dart';
import 'travle_colors.dart';

/// Builds the Travle [ThemeData] from the design tokens. Both apps call this;
/// the desktop app passes `compact: true` for denser layouts. Component themes
/// are configured here once so stock widgets pick up the styling automatically —
/// screens read the theme and never hardcode colors or text styles (doc 08).
ThemeData buildTravleTheme({bool compact = false}) {
  const colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: TravleTokens.forest,
    onPrimary: TravleTokens.mint,
    primaryContainer: TravleTokens.sage,
    onPrimaryContainer: TravleTokens.forestDarkest,
    secondary: TravleTokens.sage,
    onSecondary: TravleTokens.forestDarkest,
    secondaryContainer: TravleTokens.mint,
    onSecondaryContainer: TravleTokens.forestMid,
    tertiary: TravleTokens.forestDark,
    onTertiary: TravleTokens.mint,
    error: TravleTokens.danger,
    onError: TravleTokens.onDanger,
    surface: Colors.white,
    onSurface: TravleTokens.forestDarkest,
    onSurfaceVariant: TravleTokens.forestMid,
    outline: TravleTokens.sage,
    outlineVariant: TravleTokens.mintOutline,
  );

  final radius = BorderRadius.circular(TravleTokens.radius);

  final base = ThemeData(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: TravleTokens.mint,
    visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
    extensions: const <ThemeExtension<dynamic>>[TravleColors.light],
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: TravleTokens.forest,
      foregroundColor: TravleTokens.mint,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 1,
      margin: const EdgeInsets.all(TravleTokens.space8),
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(
          horizontal: TravleTokens.space24,
          vertical: TravleTokens.space12,
        ),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colorScheme.primary,
        side: const BorderSide(color: TravleTokens.forest),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: colorScheme.primary),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: radius),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: TravleTokens.sage),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: TravleTokens.forest, width: 2),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TravleTokens.radiusPill),
      ),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: TravleTokens.mint,
    ),
  );
}
