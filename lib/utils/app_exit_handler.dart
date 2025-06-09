import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 应用退出处理器
/// 管理双击返回键退出应用的逻辑
class AppExitHandler {
  static DateTime? _lastPressedAt;

  /// 处理返回键按下事件
  /// 返回 true 表示允许退出，false 表示拦截退出
  static bool onWillPop() {
    final now = DateTime.now();

    // 如果是第一次点击或者距离上次点击超过2秒
    if (_lastPressedAt == null ||
        now.difference(_lastPressedAt!) > const Duration(seconds: 2)) {
      _lastPressedAt = now;
      return false; // 拦截退出
    } else {
      return true; // 允许退出
    }
  }

  /// 显示退出提示
  static void showExitTip(BuildContext context) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white),
            SizedBox(width: 8),
            Text('再按一次返回键退出应用'),
          ],
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        action: SnackBarAction(
          label: '知道了',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).removeCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// 退出应用
  static void exitApp() {
    SystemNavigator.pop();
  }

  /// 重置退出状态
  /// 当用户导航到其他页面时调用
  static void reset() {
    _lastPressedAt = null;
  }
}
