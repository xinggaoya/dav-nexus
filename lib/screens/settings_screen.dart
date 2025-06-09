import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/app_settings_provider.dart';
import '../constants/app_theme.dart';
import '../services/notification_service.dart';

/// 设置页面
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      body: Consumer3<AuthProvider, ThemeProvider, AppSettingsProvider>(
        builder: (context, authProvider, themeProvider, appSettings, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 账户信息卡片
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.account_circle,
                            size: 24,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '账户信息',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow(
                        context,
                        '服务器地址',
                        authProvider.webDavUrl.isNotEmpty
                            ? authProvider.webDavUrl
                            : '未设置',
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        context,
                        '用户名',
                        authProvider.username.isNotEmpty
                            ? authProvider.username
                            : '未设置',
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pushNamedAndRemoveUntil(
                              '/login',
                              (route) => false,
                            );
                          },
                          icon: const Icon(Icons.edit),
                          label: const Text('编辑账户信息'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 外观设置卡片
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.color_lens,
                            size: 24,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '外观设置',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        leading: const Icon(Icons.brightness_6),
                        title: const Text('主题模式'),
                        subtitle: Text(themeProvider.themeModeDescription),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showThemeDialog(context, themeProvider),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 同步设置卡片
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.sync,
                            size: 24,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '同步设置',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        secondary: const Icon(Icons.sync),
                        title: const Text('自动同步'),
                        subtitle: const Text('自动同步相册和文件'),
                        value: appSettings.autoSync,
                        onChanged: appSettings.setAutoSync,
                      ),
                      if (appSettings.autoSync)
                        SwitchListTile(
                          secondary: const Icon(Icons.wifi),
                          title: const Text('仅WiFi同步'),
                          subtitle: const Text('仅在WiFi环境下自动同步'),
                          value: appSettings.autoSyncWifiOnly,
                          onChanged: appSettings.setAutoSyncWifiOnly,
                        ),
                      SwitchListTile(
                        secondary: const Icon(Icons.backup),
                        title: const Text('自动备份'),
                        subtitle: const Text('自动备份新拍摄的照片'),
                        value: appSettings.autoBackup,
                        onChanged: appSettings.setAutoBackup,
                      ),
                      SwitchListTile(
                        secondary: const Icon(Icons.notifications),
                        title: const Text('同步通知'),
                        subtitle: const Text('显示同步进度和结果通知'),
                        value: appSettings.notificationsEnabled,
                        onChanged: (value) {
                          appSettings.setNotificationsEnabled(value);
                          NotificationService.setNotificationsEnabled(value);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(value ? '通知已开启' : '通知已关闭')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 存储设置卡片
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.storage,
                            size: 24,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '存储设置',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        leading: const Icon(Icons.cached),
                        title: const Text('缓存大小'),
                        subtitle: Text('${appSettings.cacheSize} MB'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showCacheSizeDialog(context, appSettings),
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.clear_all),
                        title: const Text('清除缓存'),
                        subtitle: const Text('清除图片和文件缓存'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () =>
                            _showClearCacheDialog(context, appSettings),
                      ),
                      const Divider(),
                      SwitchListTile(
                        secondary: const Icon(Icons.visibility_off),
                        title: const Text('显示隐藏文件'),
                        subtitle: const Text('显示以点开头的隐藏文件'),
                        value: appSettings.showHiddenFiles,
                        onChanged: appSettings.setShowHiddenFiles,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 应用信息卡片
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info,
                            size: 24,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '应用信息',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        leading: const Icon(Icons.info_outline),
                        title: const Text('关于应用'),
                        subtitle: const Text('版本信息和开发者信息'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showAboutDialog(context),
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.refresh),
                        title: const Text('重置设置'),
                        subtitle: const Text('恢复所有设置到默认值'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showResetDialog(context, appSettings),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // 登出按钮
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await _showLogoutDialog(context, authProvider);
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('退出登录'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 构建信息行
  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }

  /// 显示主题设置对话框
  void _showThemeDialog(BuildContext context, ThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('选择主题模式'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: AppThemeMode.values.map((mode) {
              return RadioListTile<AppThemeMode>(
                title: Text(_getThemeModeTitle(mode)),
                subtitle: Text(_getThemeModeSubtitle(mode)),
                value: mode,
                groupValue: themeProvider.themeMode,
                onChanged: (value) {
                  if (value != null) {
                    themeProvider.setThemeMode(value);
                    Navigator.of(context).pop();
                  }
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );
  }

  /// 获取主题模式标题
  String _getThemeModeTitle(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return '浅色模式';
      case AppThemeMode.dark:
        return '深色模式';
      case AppThemeMode.system:
        return '跟随系统';
    }
  }

  /// 获取主题模式副标题
  String _getThemeModeSubtitle(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return '始终使用浅色主题';
      case AppThemeMode.dark:
        return '始终使用深色主题';
      case AppThemeMode.system:
        return '根据系统设置自动切换';
    }
  }

  /// 显示缓存大小设置对话框
  void _showCacheSizeDialog(
    BuildContext context,
    AppSettingsProvider appSettings,
  ) {
    final cacheSize = appSettings.cacheSize;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('设置缓存大小'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [50, 100, 200, 500, 1000].map((size) {
              return RadioListTile<int>(
                title: Text('$size MB'),
                value: size,
                groupValue: cacheSize,
                onChanged: (value) {
                  if (value != null) {
                    appSettings.setCacheSize(value);
                    Navigator.of(context).pop();
                  }
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );
  }

  /// 显示清除缓存确认对话框
  void _showClearCacheDialog(
    BuildContext context,
    AppSettingsProvider appSettings,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('清除缓存'),
          content: const Text('确定要清除所有缓存数据吗？这将删除已下载的图片和文件缓存。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await appSettings.clearCache();
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('缓存已清除')));
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('清除'),
            ),
          ],
        );
      },
    );
  }

  /// 显示重置设置确认对话框
  void _showResetDialog(BuildContext context, AppSettingsProvider appSettings) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('重置设置'),
          content: const Text('确定要将所有设置恢复到默认值吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await appSettings.resetAllSettings();
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('设置已重置')));
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('重置'),
            ),
          ],
        );
      },
    );
  }

  /// 显示关于对话框
  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'DAV Nexus',
      applicationVersion: '1.0.0',
      applicationIcon: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          'assets/icons/app_icon.png',
          width: 48,
          height: 48,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              Icons.cloud,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            );
          },
        ),
      ),
      children: [
        const Text('一个现代化的 WebDAV 云盘应用'),
        const SizedBox(height: 16),
        const Text('功能特性:'),
        const Text('• 文件浏览和管理'),
        const Text('• 文件上传和下载'),
        const Text('• 相册同步功能'),
        const Text('• 文件预览功能'),
        const Text('• 现代化的 Material Design 界面'),
        const Text('• 支持深色模式'),
        const Text('• 灵活的主题设置'),
      ],
    );
  }

  /// 显示登出确认对话框
  Future<void> _showLogoutDialog(
    BuildContext context,
    AuthProvider authProvider,
  ) async {
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('确认退出'),
          content: const Text('您确定要退出登录吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('退出'),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      authProvider.logout();
      if (context.mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    }
  }
}
