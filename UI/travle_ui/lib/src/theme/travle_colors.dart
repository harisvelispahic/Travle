import 'package:flutter/material.dart';

import 'tokens.dart';

/// Semantic colors the Material [ColorScheme] does not carry — success /
/// warning / info / neutral plus their on-colors. Read anywhere with
/// `Theme.of(context).extension<TravleColors>()!`; used by status pills,
/// banners, and the success/error snackbars.
@immutable
class TravleColors extends ThemeExtension<TravleColors> {
  const TravleColors({
    required this.success,
    required this.onSuccess,
    required this.warning,
    required this.onWarning,
    required this.info,
    required this.onInfo,
    required this.neutral,
    required this.onNeutral,
  });

  final Color success;
  final Color onSuccess;
  final Color warning;
  final Color onWarning;
  final Color info;
  final Color onInfo;
  final Color neutral;
  final Color onNeutral;

  static const TravleColors light = TravleColors(
    success: TravleTokens.success,
    onSuccess: TravleTokens.onSuccess,
    warning: TravleTokens.warning,
    onWarning: TravleTokens.onWarning,
    info: TravleTokens.info,
    onInfo: TravleTokens.onInfo,
    neutral: TravleTokens.neutral,
    onNeutral: TravleTokens.onNeutral,
  );

  @override
  TravleColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? warning,
    Color? onWarning,
    Color? info,
    Color? onInfo,
    Color? neutral,
    Color? onNeutral,
  }) {
    return TravleColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
      neutral: neutral ?? this.neutral,
      onNeutral: onNeutral ?? this.onNeutral,
    );
  }

  @override
  TravleColors lerp(ThemeExtension<TravleColors>? other, double t) {
    if (other is! TravleColors) {
      return this;
    }
    return TravleColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      info: Color.lerp(info, other.info, t)!,
      onInfo: Color.lerp(onInfo, other.onInfo, t)!,
      neutral: Color.lerp(neutral, other.neutral, t)!,
      onNeutral: Color.lerp(onNeutral, other.onNeutral, t)!,
    );
  }
}
