import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

/// 通知服务
class NotificationService {
  static const _channelId = 'sync_progress';
  static const _channelName = '同步进度';
  static const _channelDescription = '显示相册同步进度通知';
  static const _syncNotificationId = 1001;

  static final FlutterLocalNotificationsPlugin
  _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;
  static bool _notificationsEnabled = false;

  /// 初始化通知服务
  static Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // 请求通知权限
      final status = await Permission.notification.request();
      if (!status.isGranted) {
        if (kDebugMode) {
          print('通知权限被拒绝');
        }
        _notificationsEnabled = false;
      } else {
        _notificationsEnabled = true;
      }

      // Android 初始化设置
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS 初始化设置
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
            requestSoundPermission: false,
            requestBadgePermission: false,
            requestAlertPermission: true,
          );

      const InitializationSettings initializationSettings =
          InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsIOS,
          );

      final bool? result = await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      _isInitialized = result ?? false;

      if (_isInitialized) {
        // 创建Android通知渠道
        await _createNotificationChannel();
      }

      if (kDebugMode) {
        print('通知服务初始化${_isInitialized ? '成功' : '失败'}');
      }

      return _isInitialized;
    } catch (e) {
      if (kDebugMode) {
        print('通知服务初始化失败: $e');
      }
      return false;
    }
  }

  /// 创建Android通知渠道
  static Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
    );

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  /// 显示同步开始通知
  static Future<void> showSyncStarted() async {
    if (!_isInitialized || !_notificationsEnabled) {
      if (kDebugMode) {
        print('📱 通知: 相册同步开始');
      }
      return;
    }

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          showProgress: true,
          maxProgress: 100,
          progress: 0,
          icon: '@mipmap/ic_launcher',
          playSound: false,
          enableVibration: false,
        );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: false,
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      _syncNotificationId,
      '相册同步',
      '正在准备同步...',
      platformChannelSpecifics,
    );
  }

  /// 更新同步进度通知
  static Future<void> updateSyncProgress({
    required int current,
    required int total,
    required int uploaded,
    required int failed,
    required int skipped,
    String? currentFileName,
  }) async {
    if (!_isInitialized || !_notificationsEnabled) {
      if (kDebugMode) {
        final progress = total > 0 ? ((current / total) * 100).round() : 0;
        final progressText =
            currentFileName != null && currentFileName.isNotEmpty
            ? '正在处理: $currentFileName'
            : '正在同步相册文件...';
        print(
          '📱 通知: $progressText ($progress%) - 上传: $uploaded, 失败: $failed, 跳过: $skipped',
        );
      }
      return;
    }

    final progress = total > 0 ? ((current / total) * 100).round() : 0;
    final progressText = currentFileName != null && currentFileName.isNotEmpty
        ? '正在处理: ${_truncateFileName(currentFileName, 20)}'
        : '正在同步相册文件...';

    final subtitle =
        '进度: $current/$total | 上传: $uploaded | 失败: $failed | 跳过: $skipped';

    AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          showProgress: true,
          maxProgress: 100,
          progress: progress,
          icon: '@mipmap/ic_launcher',
          playSound: false,
          enableVibration: false,
        );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
          presentAlert: false,
          presentBadge: false,
          presentSound: false,
        );

    NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      _syncNotificationId,
      progressText,
      subtitle,
      platformChannelSpecifics,
    );
  }

  /// 显示同步完成通知
  static Future<void> showSyncCompleted({
    required int total,
    required int uploaded,
    required int failed,
    required int skipped,
  }) async {
    if (!_isInitialized || !_notificationsEnabled) {
      if (kDebugMode) {
        final title = failed > 0 ? '同步完成（有错误）' : '同步完成';
        final content =
            '总计: $total | 上传: $uploaded | 失败: $failed | 跳过: $skipped';
        print('📱 通知: $title - $content');
      }
      return;
    }

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          ongoing: false,
          autoCancel: true,
          icon: '@mipmap/ic_launcher',
          playSound: true,
          enableVibration: true,
        );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    final title = failed > 0 ? '同步完成（有错误）' : '同步完成';
    final content = '总计: $total | 上传: $uploaded | 失败: $failed | 跳过: $skipped';

    await _flutterLocalNotificationsPlugin.show(
      _syncNotificationId,
      title,
      content,
      platformChannelSpecifics,
    );
  }

  /// 显示同步暂停通知
  static Future<void> showSyncPaused({
    required int current,
    required int total,
  }) async {
    if (!_isInitialized || !_notificationsEnabled) {
      if (kDebugMode) {
        print('📱 通知: 同步已暂停 - 进度: $current/$total');
      }
      return;
    }

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          icon: '@mipmap/ic_launcher',
          playSound: false,
          enableVibration: false,
        );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: false,
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      _syncNotificationId,
      '同步已暂停',
      '进度: $current/$total - 点击应用继续',
      platformChannelSpecifics,
    );
  }

  /// 显示同步取消通知
  static Future<void> showSyncCancelled() async {
    if (!_isInitialized || !_notificationsEnabled) {
      if (kDebugMode) {
        print('📱 通知: 同步已取消');
      }
      return;
    }

    await _flutterLocalNotificationsPlugin.cancel(_syncNotificationId);

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          ongoing: false,
          autoCancel: true,
          icon: '@mipmap/ic_launcher',
          playSound: false,
          enableVibration: false,
        );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: false,
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      _syncNotificationId + 1,
      '同步已取消',
      '用户手动取消了同步操作',
      platformChannelSpecifics,
    );
  }

  /// 清除同步通知
  static Future<void> clearSyncNotification() async {
    if (!_isInitialized) {
      if (kDebugMode) {
        print('📱 通知: 清除同步通知');
      }
      return;
    }

    await _flutterLocalNotificationsPlugin.cancel(_syncNotificationId);
    await _flutterLocalNotificationsPlugin.cancel(_syncNotificationId + 1);
  }

  /// 显示错误通知
  static Future<void> showErrorNotification({
    required String title,
    required String message,
  }) async {
    if (!_isInitialized || !_notificationsEnabled) {
      if (kDebugMode) {
        print('📱 通知: $title - $message');
      }
      return;
    }

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          ongoing: false,
          autoCancel: true,
          icon: '@mipmap/ic_launcher',
          playSound: true,
          enableVibration: true,
        );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      _syncNotificationId + 2,
      title,
      message,
      platformChannelSpecifics,
    );
  }

  /// 启用/禁用通知
  static void setNotificationsEnabled(bool enabled) {
    _notificationsEnabled = enabled;
  }

  /// 检查通知是否启用
  static bool get isNotificationsEnabled => _notificationsEnabled;

  /// 检查通知权限状态
  static Future<bool> checkNotificationPermission() async {
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  /// 请求通知权限
  static Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    _notificationsEnabled = status.isGranted;
    return status.isGranted;
  }

  /// 截断文件名
  static String _truncateFileName(String fileName, int maxLength) {
    if (fileName.length <= maxLength) {
      return fileName;
    }
    return '${fileName.substring(0, maxLength - 3)}...';
  }

  /// 处理通知点击事件
  static void _onNotificationTap(NotificationResponse notificationResponse) {
    if (kDebugMode) {
      print('通知被点击: ${notificationResponse.payload}');
    }
    // 这里可以处理点击通知后的逻辑，比如打开应用的特定页面
    // 可以根据notificationResponse.id来判断是哪种类型的通知
    final notificationId = notificationResponse.id ?? 0;
    if (notificationId == _syncNotificationId) {
      // 同步相关通知被点击，可以导航到同步页面
    } else if (notificationId == _syncNotificationId + 1) {
      // 取消通知被点击
    } else if (notificationId == _syncNotificationId + 2) {
      // 错误通知被点击
    }
  }
}
