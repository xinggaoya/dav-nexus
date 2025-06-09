# DAV Nexus - 专业的 WebDAV 云盘应用

## 项目简介

DAV Nexus 是一个功能丰富的跨平台 WebDAV 云盘客户端应用，使用 Flutter 开发。它提供了完整的文件管理功能、智能相册同步以及现代化的用户界面。

### 主要特性

- 🌐 **全平台支持**: Windows、macOS、Linux、iOS、Android、Web
- 📁 **完整文件管理**: 浏览、上传、下载、删除、重命名文件和文件夹
- 📱 **智能相册同步**: 自动将本地相册照片同步到 WebDAV 服务器
- 🔍 **多视图模式**: 支持列表视图和网格视图
- 🎨 **现代化 UI**: Material Design 设计，支持浅色/深色主题
- 🚀 **高性能**: 多线程文件操作，缓存优化
- 🔐 **安全可靠**: 支持基础认证，数据加密传输
- 📊 **详细统计**: 文件大小、修改时间、同步状态等信息

## 技术栈

### 核心技术

- **Flutter**: 3.8.1+ - 跨平台 UI 框架
- **Dart**: 3.8.1+ - 编程语言

### 主要依赖

- **网络请求**: `dio` (HTTP 客户端), `http`
- **WebDAV 客户端**: `webdav_client`
- **状态管理**: `provider`
- **数据持久化**: `shared_preferences`, `sqflite`
- **文件操作**: `path_provider`, `file_picker`
- **相册管理**: `photo_manager`
- **权限管理**: `permission_handler`
- **UI 组件**: `cached_network_image`, `flutter_spinkit`, `flutter_svg`
- **工具库**: `xml`, `crypto`, `intl`, `filesize`

## 项目结构

```
dav_nexus/
├── lib/
│   ├── main.dart                 # 应用入口
│   ├── constants/                # 常量配置
│   │   ├── app_constants.dart    # 应用常量
│   │   └── app_theme.dart        # 主题配置
│   ├── models/                   # 数据模型
│   │   ├── webdav_file.dart      # WebDAV文件模型
│   │   └── photo_sync_record.dart # 相册同步记录模型
│   ├── providers/                # 状态管理
│   │   ├── auth_provider.dart    # 认证状态管理
│   │   └── file_provider.dart    # 文件状态管理
│   ├── screens/                  # 页面
│   │   ├── login_screen.dart     # 登录页面
│   │   ├── home_screen.dart      # 主页面(文件管理)
│   │   ├── settings_screen.dart  # 设置页面
│   │   └── photo_sync_screen.dart # 相册同步页面
│   ├── services/                 # 业务服务
│   │   ├── webdav_service.dart   # WebDAV服务
│   │   ├── photo_sync_service.dart # 相册同步服务
│   │   └── sync_database_service.dart # 同步数据库服务
│   └── widgets/                  # 公共组件
├── assets/                       # 资源文件
│   ├── images/                   # 图片资源
│   └── icons/                    # 图标资源
├── android/                      # Android平台配置
├── ios/                          # iOS平台配置
├── linux/                        # Linux平台配置
├── macos/                        # macOS平台配置
├── web/                          # Web平台配置
├── windows/                      # Windows平台配置
├── pubspec.yaml                  # 项目依赖配置
└── README.md                     # 项目说明文档
```

## 环境要求

### 开发环境

- **Flutter SDK**: 3.8.1 或更高版本
- **Dart SDK**: 3.8.1 或更高版本
- **操作系统**: Windows 10+, macOS 10.14+, Linux (Ubuntu 18.04+)

### 平台特定要求

#### Android 开发

- **Android Studio**: 2022.1 或更高版本
- **Android SDK**: API 21 (Android 5.0) 或更高版本
- **Java**: JDK 11 或更高版本

#### iOS 开发 (仅 macOS)

- **Xcode**: 14.0 或更高版本
- **iOS**: 11.0 或更高版本
- **CocoaPods**: 最新版本

#### Web 开发

- **Chrome**: 最新版本 (用于调试)

#### Desktop 开发

- **Visual Studio**: 2022 (Windows)
- **Clang**: 最新版本 (Linux/macOS)

## 快速开始

### 1. 克隆项目

```bash
git clone https://github.com/your-username/dav_nexus.git
cd dav_nexus
```

### 2. 安装依赖

```bash
flutter pub get
```

### 3. 检查环境

```bash
flutter doctor
```

### 4. 运行应用

#### 调试模式运行 (推荐用于开发)

```bash
# Android
flutter run -d android

# iOS (仅macOS)
flutter run -d ios

# Web
flutter run -d chrome

# Windows
flutter run -d windows

# macOS
flutter run -d macos

# Linux
flutter run -d linux
```

#### 查看可用设备

```bash
flutter devices
```

#### 指定设备运行

```bash
flutter run -d <device-id>
```

## 构建和打包

### Android APK

```bash
# 构建调试版APK
flutter build apk --debug

# 构建发布版APK
flutter build apk --release

# 构建分平台APK (减小体积)
flutter build apk --split-per-abi --release
```

### Android App Bundle (推荐用于 Google Play)

```bash
flutter build appbundle --release
```

### iOS (仅 macOS)

```bash
# 构建iOS应用
flutter build ios --release

# 构建IPA文件
flutter build ipa --release
```

### Web 应用

```bash
# 构建Web应用
flutter build web --release

# 指定Web渲染器
flutter build web --release --web-renderer html
flutter build web --release --web-renderer canvaskit
```

### Windows 应用

```bash
# 构建Windows应用
flutter build windows --release
```

### macOS 应用

```bash
# 构建macOS应用
flutter build macos --release
```

### Linux 应用

```bash
# 构建Linux应用
flutter build linux --release
```

## 配置说明

### WebDAV 服务器配置

应用支持任何标准的 WebDAV 服务器，包括但不限于：

- **Nextcloud**
- **ownCloud**
- **Synology NAS**
- **坚果云**
- **Apache WebDAV**
- **Nginx WebDAV**

### 默认配置

在 `lib/constants/app_constants.dart` 中可以修改默认配置：

```dart
class AppConstants {
  // WebDAV服务器配置
  static const String defaultWebDavUrl = 'https://your-server.com/dav';
  static const String defaultUsername = 'your-username';
  static const String defaultPassword = 'your-password';

  // 其他配置...
}
```

### 权限配置

#### Android 权限 (`android/app/src/main/AndroidManifest.xml`)

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
```

#### iOS 权限 (`ios/Runner/Info.plist`)

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>此应用需要访问相册以同步照片到云端</string>
<key>NSCameraUsageDescription</key>
<string>此应用需要访问相机以拍照并同步到云端</string>
```

## 开发指南

### 代码规范

- 遵循 [Dart 官方代码规范](https://dart.dev/guides/language/effective-dart)
- 使用 `flutter analyze` 检查代码质量
- 使用 `dart format` 格式化代码

### 目录规范

- **models/**: 数据模型，包含业务实体定义
- **providers/**: 状态管理，使用 Provider 模式
- **services/**: 业务逻辑服务层
- **screens/**: 页面组件
- **widgets/**: 可复用的 UI 组件
- **constants/**: 常量和配置

### 状态管理

项目使用 Provider 进行状态管理：

- `AuthProvider`: 管理用户认证状态
- `FileProvider`: 管理文件列表和操作状态

### 数据库设计

使用 SQLite 存储本地数据：

- 相册同步记录
- 用户设置
- 缓存数据

## 调试和测试

### 运行测试

```bash
# 运行所有测试
flutter test

# 运行特定测试
flutter test test/widget_test.dart

# 生成测试覆盖率报告
flutter test --coverage
```

### 调试工具

- **Flutter Inspector**: 用于 UI 调试
- **Network Inspector**: 用于网络请求调试
- **Memory Inspector**: 用于内存使用分析

### 日志输出

```bash
# 查看应用日志
flutter logs

# 查看特定设备日志
flutter logs -d <device-id>
```

## 性能优化

### 构建优化

```bash
# 启用混淆和压缩
flutter build apk --release --obfuscate --split-debug-info=build/debug-info

# Web构建优化
flutter build web --release --tree-shake-icons
```

### 代码优化建议

- 使用 `const` 构造函数减少重建
- 合理使用 `ListView.builder` 处理大列表
- 实现图片缓存和懒加载
- 使用 `async`/`await` 处理异步操作

## 常见问题

### 1. 构建失败

```bash
# 清理构建缓存
flutter clean
flutter pub get

# 升级依赖
flutter pub upgrade
```

### 2. 网络请求失败

- 检查 WebDAV 服务器 URL 是否正确
- 确认用户名密码是否正确
- 检查网络连接和防火墙设置

### 3. 权限问题

- 确保已正确配置平台权限
- 在应用中正确请求运行时权限

### 4. 相册同步问题

- 检查相册访问权限
- 确认存储空间是否充足
- 检查 WebDAV 服务器存储配额

## 贡献指南

1. Fork 项目
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 创建 Pull Request

## 版本历史

- **v1.0.0** - 初始版本
  - 基础 WebDAV 文件管理功能
  - 相册同步功能
  - 跨平台支持

## 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 联系方式

- **项目维护者**: [您的名字]
- **邮箱**: your-email@example.com
- **问题反馈**: [GitHub Issues](https://github.com/your-username/dav_nexus/issues)

## 致谢

感谢以下开源项目：

- [Flutter](https://flutter.dev/)
- [webdav_client](https://pub.dev/packages/webdav_client)
- [provider](https://pub.dev/packages/provider)
- [photo_manager](https://pub.dev/packages/photo_manager)

---

📱 **Happy Coding!** 希望这个项目对您有帮助。如果您有任何问题或建议，请随时联系我们。
