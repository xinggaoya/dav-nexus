import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../services/webdav_service.dart';

/// 认证状态管理
class AuthProvider extends ChangeNotifier {
  bool _isLoggedIn = false;
  bool _isLoading = false;
  String? _errorMessage;
  WebDavService? _webDavService;

  // 登录表单字段
  String _webDavUrl = '';
  String _username = '';
  String _password = '';
  bool _rememberCredentials = true;

  // Getters
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  WebDavService? get webDavService => _webDavService;
  String get webDavUrl => _webDavUrl;
  String get username => _username;
  String get password => _password;
  bool get rememberCredentials => _rememberCredentials;

  AuthProvider() {
    _loadSavedCredentials();
  }

  /// 加载保存的凭据
  Future<void> _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _isLoggedIn = prefs.getBool(AppConstants.keyIsLoggedIn) ?? false;

      // 从保存的数据中加载WebDAV URL
      _webDavUrl = prefs.getString(AppConstants.keyWebDavUrl) ?? '';

      _username = prefs.getString(AppConstants.keyUsername) ?? '';
      _password = prefs.getString(AppConstants.keyPassword) ?? '';
      _rememberCredentials =
          prefs.getBool(AppConstants.keyRememberCredentials) ?? true;

      // 如果已登录且有完整的凭据，创建WebDAV服务实例
      if (_isLoggedIn && _webDavUrl.isNotEmpty) {
        _webDavService = WebDavService(
          baseUrl: _webDavUrl,
          username: _username,
          password: _password,
        );
      }

      notifyListeners();
    } catch (e) {
      _errorMessage = '加载保存的凭据失败: $e';
      notifyListeners();
    }
  }

  /// 保存凭据到本地
  Future<void> _saveCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool(AppConstants.keyIsLoggedIn, _isLoggedIn);

      if (_rememberCredentials) {
        await prefs.setString(AppConstants.keyWebDavUrl, _webDavUrl);
        await prefs.setString(AppConstants.keyUsername, _username);
        await prefs.setString(AppConstants.keyPassword, _password);
      } else {
        // 如果不记住凭据，清除保存的信息
        await prefs.remove(AppConstants.keyWebDavUrl);
        await prefs.remove(AppConstants.keyUsername);
        await prefs.remove(AppConstants.keyPassword);
      }

      await prefs.setBool(
        AppConstants.keyRememberCredentials,
        _rememberCredentials,
      );
    } catch (e) {
      _errorMessage = '保存凭据失败: $e';
      notifyListeners();
    }
  }

  /// 更新表单字段
  void updateWebDavUrl(String url) {
    _webDavUrl = url;
    notifyListeners();
  }

  void updateUsername(String username) {
    _username = username;
    notifyListeners();
  }

  void updatePassword(String password) {
    _password = password;
    notifyListeners();
  }

  void updateRememberCredentials(bool remember) {
    _rememberCredentials = remember;
    notifyListeners();
  }

  /// 清除错误信息
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// 登录
  Future<bool> login() async {
    if (_isLoading) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 验证输入
      if (_webDavUrl.isEmpty || _username.isEmpty || _password.isEmpty) {
        throw Exception('请填写完整的登录信息');
      }

      // 创建WebDAV服务实例
      final webDavService = WebDavService(
        baseUrl: _webDavUrl,
        username: _username,
        password: _password,
      );

      // 测试连接
      final isConnected = await webDavService.testConnection();

      if (!isConnected) {
        throw Exception('无法连接到WebDAV服务器，请检查URL和凭据');
      }

      // 登录成功
      _isLoggedIn = true;
      _webDavService = webDavService;

      // 保存凭据
      await _saveCredentials();

      _isLoading = false;
      notifyListeners();

      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 登出
  Future<void> logout() async {
    try {
      _isLoggedIn = false;
      _webDavService?.dispose();
      _webDavService = null;

      // 清除登录状态
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.keyIsLoggedIn, false);

      // 如果不记住凭据，清除所有保存的信息
      if (!_rememberCredentials) {
        await prefs.remove(AppConstants.keyWebDavUrl);
        await prefs.remove(AppConstants.keyUsername);
        await prefs.remove(AppConstants.keyPassword);

        // 重置为默认值
        _webDavUrl = '';
        _username = '';
        _password = '';
      }
      // 如果记住凭据，保留服务器地址、用户名和密码，但重置登录状态

      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = '登出失败: $e';
      notifyListeners();
    }
  }

  /// 重新连接（用于网络错误恢复）
  Future<bool> reconnect() async {
    if (_webDavService == null) return false;

    try {
      final isConnected = await _webDavService!.testConnection();
      if (!isConnected) {
        _errorMessage = '网络连接失败，请检查网络设置';
        notifyListeners();
      }
      return isConnected;
    } catch (e) {
      _errorMessage = '重新连接失败: $e';
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _webDavService?.dispose();
    super.dispose();
  }
}
