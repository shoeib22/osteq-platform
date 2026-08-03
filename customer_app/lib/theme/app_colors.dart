import 'package:flutter/material.dart';

/// Dark premium/luxury palette — near-black surfaces, warm gold accent. Every screen in
/// this app pulls colors from here rather than inlining hex values, so the whole app's
/// look stays a single coherent system instead of drifting screen-by-screen.
class AppColors {
  AppColors._();

  static const background = Color(0xFF0B0B0D);
  static const surface = Color(0xFF17171B);
  static const surfaceRaised = Color(0xFF1F1F24);
  static const border = Color(0xFF2A2A31);

  static const gold = Color(0xFFC9A227);
  static const goldMuted = Color(0xFF8C7A3D);

  static const textPrimary = Color(0xFFF2F0EA);
  static const textSecondary = Color(0xFFA6A299);
  static const textDisabled = Color(0xFF5C5A57);

  static const success = Color(0xFF4CAF7D);
  static const error = Color(0xFFE5626A);
}
