import 'package:flutter/material.dart';

class AppColors {
  // Theme Backgrounds
  static const Color bgLight = Color(0xFFFFFFFF);
  static const Color bgDark = Color(0xFF191B28);
  static const Color bgCream = Color(0xFFF9F6F0);

  // Line Colors (Charcoal Black for light/cream, White for dark)
  static const Color lineDark = Color(0xFF1E1E24);
  static const Color lineLight = Color(0xFFF0F0F5);

  // Grid Dots
  static const Color gridDotLight = Color(0xFFE5E7EB);
  static const Color gridDotDark = Color(0xFF2D3042);
  static const Color gridDotCream = Color(0xFFE8E3D8);

  // UI Accents
  static const Color buttonBlue = Color(0xFF5E72EB);
  static const Color heartActive = Color(0xFFFF5B62); // Coral Red

  // States
  static const Color errorFlash = Color(0xFFFF5B62); // Red for trapped
  static const Color successHighlight = Color(0xFF4ADE80); // Green for free

  // Legacy aliases — used by game_screen.dart and other screens that haven't been
  // refactored to ThemeProvider yet. Defaults to the light-mode values.
  static const Color background = bgLight;
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceBorder = Color(0xFFE5E7EB);
  static const Color textPrimary = Color(0xFF1A1C29);
  static const Color textSecondary = Color(0xFF7B7E99);
  static const Color primary = buttonBlue;
  static const Color textLight = Color(0xFF1A1C29);
  static const Color textDark = Color(0xFFF2ECE4);
}
