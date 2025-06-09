import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 应用设置管理
class AppSettingsProvider extends ChangeNotifier {
  static const String _keyAutoSync = 'auto_sync';
  static const String _keyAutoSyncWifiOnly = 'auto_sync_wifi_only';
  static const String _keyCacheSize = 'cache_size';
  static const String _keyShowHiddenFiles = 'show_hidden_files';
  static const String _keyAutoBackup = 'auto_backup';
  static const String _keyNotificationsEnabled = 'notifications_enabled';

  bool _autoSync = false;
  bool _autoSyncWifiOnly = true;
  int _cacheSize = 100; // MB
  bool _showHiddenFiles = false;
  bool _autoBackup = false;
  bool _notificationsEnabled = true;

  // Getters
  bool get autoSync => _autoSync;
  bool get autoSyncWifiOnly => _autoSyncWifiOnly;
  int get cacheSize => _cacheSize;
  bool get showHiddenFiles => _showHiddenFiles;
  bool get autoBackup => _autoBackup;
  bool get notificationsEnabled => _notificationsEnabled;

  AppSettingsProvider() {
    _loadSettings();
  }

  /// 加载设置
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _autoSync = prefs.getBool(_keyAutoSync) ?? false;
      _autoSyncWifiOnly = prefs.getBool(_keyAutoSyncWifiOnly) ?? true;
      _cacheSize = prefs.getInt(_keyCacheSize) ?? 100;
      _showHiddenFiles = prefs.getBool(_keyShowHiddenFiles) ?? false;
      _autoBackup = prefs.getBool(_keyAutoBackup) ?? false;
      _notificationsEnabled = prefs.getBool(_keyNotificationsEnabled) ?? true;

      notifyListeners();
    } catch (e) {
      debugPrint('加载应用设置失败: $e');
    }
  }

  /// 设置自动同步
  Future<void> setAutoSync(bool value) async {
    if (_autoSync == value) return;

    _autoSync = value;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyAutoSync, value);
    } catch (e) {
      debugPrint('保存自动同步设置失败: $e');
    }
  }

  /// 设置仅WiFi同步
  Future<void> setAutoSyncWifiOnly(bool value) async {
    if (_autoSyncWifiOnly == value) return;

    _autoSyncWifiOnly = value;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyAutoSyncWifiOnly, value);
    } catch (e) {
      debugPrint('保存WiFi同步设置失败: $e');
    }
  }

  /// 设置缓存大小
  Future<void> setCacheSize(int size) async {
    if (_cacheSize == size) return;

    _cacheSize = size;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyCacheSize, size);
    } catch (e) {
      debugPrint('保存缓存大小设置失败: $e');
    }
  }

  /// 设置显示隐藏文件
  Future<void> setShowHiddenFiles(bool value) async {
    if (_showHiddenFiles == value) return;

    _showHiddenFiles = value;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyShowHiddenFiles, value);
    } catch (e) {
      debugPrint('保存显示隐藏文件设置失败: $e');
    }
  }

  /// 设置自动备份
  Future<void> setAutoBackup(bool value) async {
    if (_autoBackup == value) return;

    _autoBackup = value;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyAutoBackup, value);
    } catch (e) {
      debugPrint('保存自动备份设置失败: $e');
    }
  }

  /// 设置通知开关
  Future<void> setNotificationsEnabled(bool value) async {
    if (_notificationsEnabled == value) return;

    _notificationsEnabled = value;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyNotificationsEnabled, value);
    } catch (e) {
      debugPrint('保存通知设置失败: $e');
    }
  }

  /// 清除缓存
  Future<void> clearCache() async {
    // TODO: 实现清除缓存逻辑
    // 这里可以清除图片缓存等
    notifyListeners();
  }

  /// 重置所有设置
  Future<void> resetAllSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.remove(_keyAutoSync);
      await prefs.remove(_keyAutoSyncWifiOnly);
      await prefs.remove(_keyCacheSize);
      await prefs.remove(_keyShowHiddenFiles);
      await prefs.remove(_keyAutoBackup);
      await prefs.remove(_keyNotificationsEnabled);

      // 重置为默认值
      _autoSync = false;
      _autoSyncWifiOnly = true;
      _cacheSize = 100;
      _showHiddenFiles = false;
      _autoBackup = false;
      _notificationsEnabled = true;

      notifyListeners();
    } catch (e) {
      debugPrint('重置设置失败: $e');
    }
  }
}
