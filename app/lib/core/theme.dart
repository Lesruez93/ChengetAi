import 'package:flutter/material.dart';

/// Brand and semantic colors.
///
/// ChengetAI is a trust & safety app, not a horror-movie warning system —
/// the palette leans on a reassuring teal/green as the primary brand color.
/// Red is reserved for genuine danger signals (scam verdicts, high-risk
/// numbers, red hotspots) so it keeps its meaning instead of being ambient
/// decoration.
abstract final class AppColors {
  static const Color brandPrimary = Color(0xFF0F6B5C); // deep teal
  static const Color brandSecondary = Color(0xFF14A085); // lighter teal accent
  static const Color surfaceTint = Color(0xFFF4FAF8);

  // Verdict / risk-level semantics — used consistently across VerdictCard,
  // NumberReputationCard, RiskChip and the feed hotspot list.
  static const Color danger = Color(0xFFC62828); // scam / high risk / red hotspot
  static const Color warning = Color(0xFFB8860B); // suspicious / medium risk / yellow hotspot
  static const Color safe = Color(0xFF2E7D32); // safe / low risk / green hotspot
  static const Color neutral = Color(0xFF64748B); // unknown / no data

  static Color forHotspotLevel(String level) {
    switch (level) {
      case 'red':
        return danger;
      case 'yellow':
        return warning;
      case 'green':
        return safe;
      default:
        return neutral;
    }
  }

  static Color forVerdict(String verdict) {
    switch (verdict) {
      case 'scam':
        return danger;
      case 'suspicious':
        return warning;
      case 'safe':
        return safe;
      default:
        return neutral;
    }
  }

  static Color forRiskLevel(String riskLevel) {
    switch (riskLevel) {
      case 'high':
        return danger;
      case 'medium':
        return warning;
      case 'low':
        return safe;
      default:
        return neutral;
    }
  }
}

ThemeData buildAppTheme() {
  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: AppColors.brandPrimary,
    primary: AppColors.brandPrimary,
    secondary: AppColors.brandSecondary,
    brightness: Brightness.light,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.surfaceTint,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.brandPrimary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
    // Tabs live inside the (dark teal) AppBar, so labels need to be light —
    // the Material 3 default label colors assume a light surface and are
    // nearly invisible on brandPrimary otherwise.
    tabBarTheme: TabBarThemeData(
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white.withOpacity(0.7),
      indicatorColor: Colors.white,
    ),
    cardTheme: CardThemeData(
      elevation: 1,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.brandPrimary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.grey.shade100,
      labelStyle: const TextStyle(fontSize: 12.5),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.shade300),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: AppColors.brandPrimary.withOpacity(0.12),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}
