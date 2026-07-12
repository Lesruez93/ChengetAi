import 'package:flutter/material.dart';

/// The ChengetAI shield mark, used as the `leading` widget on each tab's
/// AppBar so the brand is visible throughout the app, not just at first
/// launch. Source: docs/assets/logo-mark.png in the repo root.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Image.asset('assets/branding/logo-mark.png', width: size, height: size),
    );
  }
}
