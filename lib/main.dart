import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'constants/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/file_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/app_settings_provider.dart';
import 'services/notification_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/photo_sync_screen.dart';
import 'utils/app_exit_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化通知服务
  await NotificationService.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => FileProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AppSettingsProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'DAV Nexus',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.flutterThemeMode,
            debugShowCheckedModeBanner: false,
            home: const AuthWrapper(),
            routes: {
              '/login': (context) => const LoginScreen(),
              '/home': (context) => const HomeScreen(),
              '/settings': (context) => const SettingsScreen(),
              '/photo_sync': (context) => const PhotoSyncScreen(),
            },
          );
        },
      ),
    );
  }
}

/// 认证包装器 - 根据登录状态显示不同页面
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // 如果已登录，显示主页面并包装双击退出功能
        if (authProvider.isLoggedIn) {
          return PopScope(
            canPop: false,
            onPopInvoked: (didPop) async {
              if (didPop) return;

              // 使用工具类处理退出逻辑
              if (AppExitHandler.onWillPop()) {
                AppExitHandler.exitApp();
              } else {
                if (mounted) {
                  AppExitHandler.showExitTip(context);
                }
              }
            },
            child: const HomeScreen(),
          );
        }

        // 否则显示登录页面（登录页面不需要双击退出功能）
        return const LoginScreen();
      },
    );
  }
}
