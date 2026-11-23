import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../core/theme/app_colors.dart';

enum AppThemeMode { light, dark, cream }

class ThemeProvider extends ChangeNotifier {
  static const String _boxName = 'settingsBox';
  static const String _themeKey = 'themeMode';

  AppThemeMode _currentMode = AppThemeMode.light;

  AppThemeMode get currentMode => _currentMode;

  ThemeProvider() {
    _loadTheme();
  }

  void _loadTheme() {
    var box = Hive.box(_boxName);
    String? storedTheme = box.get(_themeKey);
    if (storedTheme != null) {
      _currentMode = AppThemeMode.values.firstWhere(
        (e) => e.toString() == storedTheme,
        orElse: () => AppThemeMode.light,
      );
    }
    notifyListeners();
  }

  void setTheme(AppThemeMode mode) {
    _currentMode = mode;
    var box = Hive.box(_boxName);
    box.put(_themeKey, mode.toString());
    notifyListeners();
  }

  Color get backgroundColor {
    switch (_currentMode) {
      case AppThemeMode.light:
        return AppColors.bgLight;
      case AppThemeMode.dark:
        return AppColors.bgDark;
      case AppThemeMode.cream:
        return AppColors.bgCream;
    }
  }

  Color get gridDotColor {
    switch (_currentMode) {
      case AppThemeMode.light:
        return AppColors.gridDotLight;
      case AppThemeMode.dark:
        return AppColors.gridDotDark;
      case AppThemeMode.cream:
        return AppColors.gridDotCream;
    }
  }

  Color get lineColor {
    switch (_currentMode) {
      case AppThemeMode.light:
      case AppThemeMode.cream:
        return AppColors.lineDark; // Charcoal black for light/cream
      case AppThemeMode.dark:
        return AppColors.lineLight; // White-ish for dark mode
    }
  }

  Color get textColor {
    switch (_currentMode) {
      case AppThemeMode.light:
      case AppThemeMode.cream:
        return AppColors.textLight;
      case AppThemeMode.dark:
        return AppColors.textDark;
    }
  }

  Color get textSecondaryColor {
    return textColor.withAlpha(150);
  }

  Color get surfaceColor {
    switch (_currentMode) {
      case AppThemeMode.light:
        return Colors.white;
      case AppThemeMode.cream:
        return Colors.white;
      case AppThemeMode.dark:
        return const Color(0xFF232533);
    }
  }

  Color get surfaceBorderColor {
    switch (_currentMode) {
      case AppThemeMode.light:
        return Colors.grey.shade200;
      case AppThemeMode.cream:
        return const Color(0xFFE8E3D8);
      case AppThemeMode.dark:
        return const Color(0xFF323546);
    }
  }

  Color get primaryColor {
    return AppColors.buttonBlue;
  }
}
