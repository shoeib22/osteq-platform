import 'package:flutter/material.dart';

/// The real Osteq brand mark (pulled from osteq.in) — used anywhere the app needs to
/// identify itself (catalog app bar, login/signup) instead of a plain text title.
class OsteqLogo extends StatelessWidget {
  const OsteqLogo({super.key, this.height = 28});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/osteq_logo.png',
      height: height,
      fit: BoxFit.contain,
    );
  }
}
