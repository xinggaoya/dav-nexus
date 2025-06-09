import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 主题模式枚举
enum AppThemeMode { light, dark, system }

/// 主题设置管理
class ThemeProvider extends ChangeNotifier {
  static const String _keyThemeMode = 'theme_mode';

  AppThemeMode _themeMode = AppThemeMode.system;

  AppThemeMode get themeMode => _themeMode;

  /// 获取 Flutter 主题模式
  ThemeMode get flutterThemeMode {
    switch (_themeMode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  /// 获取主题模式描述
  String get themeModeDescription {
    switch (_themeMode) {
      case AppThemeMode.light:
        return '浅色模式';
      case AppThemeMode.dark:
        return '深色模式';
      case AppThemeMode.system:
        return '跟随系统';
    }
  }

  ThemeProvider() {
    _loadThemeMode();
  }

  /// 加载保存的主题模式
  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeModeIndex =
          prefs.getInt(_keyThemeMode) ?? AppThemeMode.system.index;
      _themeMode = AppThemeMode.values[themeModeIndex];
      notifyListeners();
    } catch (e) {
      // 如果加载失败，使用默认值
      _themeMode = AppThemeMode.system;
    }
  }

  /// 设置主题模式
  Future<void> setThemeMode(AppThemeMode mode) async {
    if (_themeMode == mode) return;

    _themeMode = mode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyThemeMode, mode.index);
    } catch (e) {
      // 保存失败时的错误处理
      debugPrint('保存主题设置失败: $e');
    }
  }

  /// 切换到下一个主题模式
  Future<void> toggleThemeMode() async {
    AppThemeMode nextMode;
    switch (_themeMode) {
      case AppThemeMode.light:
        nextMode = AppThemeMode.dark;
        break;
      case AppThemeMode.dark:
        nextMode = AppThemeMode.system;
        break;
      case AppThemeMode.system:
        nextMode = AppThemeMode.light;
        break;
    }
    await setThemeMode(nextMode);
  }
}
