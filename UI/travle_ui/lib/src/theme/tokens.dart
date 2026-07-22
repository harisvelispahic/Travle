import 'package:flutter/material.dart';

/// Design tokens — the single source of truth for the palette, spacing scale,
/// and corner radii. Screens consume these through the theme (or these consts
/// directly only where a raw value is unavoidable, e.g. a gradient). See doc 08.
class TravleTokens {
  TravleTokens._();

  // Brand palette (darkest → lightest).
  static const Color forestDarkest = Color(0xFF051F20);
  static const Color forestDark = Color(0xFF0B2B26);
  static const Color forestMid = Color(0xFF153832);
  static const Color forest = Color(0xFF235347);
  static const Color sage = Color(0xFF8EB69B);
  static const Color mint = Color(0xFFDAF1DD);

  /// Faint mint tint for outline variants / dividers.
  static const Color mintOutline = Color(0xFFC7DED0);

  // Semantic status colors (status pills, banners, snackbars).
  static const Color success = Color(0xFF2E7D5B);
  static const Color onSuccess = Color(0xFFFFFFFF);
  static const Color warning = Color(0xFFE0A800);
  static const Color onWarning = Color(0xFF1A1A1A);
  static const Color info = Color(0xFF2D6CDF);
  static const Color onInfo = Color(0xFFFFFFFF);
  static const Color danger = Color(0xFFC0392B);
  static const Color onDanger = Color(0xFFFFFFFF);
  static const Color neutral = Color(0xFF6B7280);
  static const Color onNeutral = Color(0xFFFFFFFF);

  // Spacing scale (4 / 8 / 12 / 16 / 24 / 32).
  static const double space4 = 4;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space24 = 24;
  static const double space32 = 32;

  // Corner radii.
  static const double radius = 12; // cards, dialogs, inputs
  static const double radiusPill = 999; // chips, pills
}
