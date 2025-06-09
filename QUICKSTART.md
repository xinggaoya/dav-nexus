# DAV Nexus 快速开始指南

## 🚀 一键运行命令

### 前置条件检查

```bash
# 检查Flutter环境
flutter doctor

# 确保Flutter版本 >= 3.8.1
flutter --version
```

### 项目初始化

```bash
# 1. 克隆项目 (如果还没有)
git clone <your-repo-url>
cd dav_nexus

# 2. 安装依赖
flutter pub get

# 3. 清理缓存 (可选，解决依赖问题时使用)
flutter clean
flutter pub get
```

## 📱 按平台运行

### Android 📲

```bash
# 快速运行到Android设备/模拟器
flutter run

# 或指定Android平台
flutter run -d android

# 发布版本 (用于性能测试)
flutter run --release -d android
```

**Android 设备要求:**

- Android 5.0 (API 21) 或更高版本
- 开启开发者选项和 USB 调试

### iOS 🍎 (仅限 macOS)

```bash
# 运行到iOS设备/模拟器
flutter run -d ios

# 运行到特定iOS设备
flutter devices  # 查看设备列表
flutter run -d "iPhone Simulator"

# 发布版本
flutter run --release -d ios
```

**iOS 设备要求:**

- iOS 11.0 或更高版本
- Xcode 14.0 或更高版本

### Web 🌐

```bash
# 运行Web版本 (Chrome)
flutter run -d chrome

# 指定端口
flutter run -d web-server --web-port 8080

# 发布版本
flutter run --release -d chrome
```

**Web 要求:**

- Chrome 浏览器最新版本
- 网络连接 (访问 WebDAV 服务器)

### Windows 🪟

```bash
# 运行Windows桌面应用
flutter run -d windows

# 发布版本
flutter run --release -d windows
```

**Windows 要求:**

- Windows 10 或更高版本
- Visual Studio 2022 (包含 C++工具)

### macOS 🖥️

```bash
# 运行macOS桌面应用
flutter run -d macos

# 发布版本
flutter run --release -d macos
```

**macOS 要求:**

- macOS 10.14 或更高版本
- Xcode 命令行工具

### Linux 🐧

```bash
# 运行Linux桌面应用
flutter run -d linux

# 发布版本
flutter run --release -d linux
```

**Linux 要求:**

- Ubuntu 18.04+ 或其他兼容发行版
- 必要的开发库 (通过脚本自动安装)

## 🔧 开发模式功能

### 热重载

开发时，修改代码后按 `r` 键即可热重载，无需重新启动应用。

### 调试模式

```bash
# 运行调试版本 (默认)
flutter run

# 查看详细输出
flutter run -v

# 启用性能监控
flutter run --enable-software-rendering
```

### 多设备同时运行

```bash
# 在多个设备上同时运行
flutter run -d all
```

## 🏗️ 构建发布版本

### Android APK

```bash
# 构建发布APK
flutter build apk --release

# 分架构构建 (减小包体积)
flutter build apk --split-per-abi --release

# 构建AAB (Google Play推荐)
flutter build appbundle --release
```

输出位置: `build/app/outputs/flutter-apk/`

### iOS IPA (仅 macOS)

```bash
# 构建iOS应用
flutter build ios --release

# 构建IPA文件
flutter build ipa --release
```

输出位置: `build/ios/ipa/`

### Web 应用

```bash
# 构建Web应用
flutter build web --release

# 使用Canvas Kit渲染器 (更好的性能)
flutter build web --release --web-renderer canvaskit
```

输出位置: `build/web/`

### 桌面应用

#### Windows

```bash
flutter build windows --release
```

输出位置: `build/windows/runner/Release/`

#### macOS

```bash
flutter build macos --release
```

输出位置: `build/macos/Build/Products/Release/`

#### Linux

```bash
flutter build linux --release
```

输出位置: `build/linux/x64/release/bundle/`

## ⚙️ 配置 WebDAV 服务器

### 快速测试配置

在 `lib/constants/app_constants.dart` 中修改默认配置:

```dart
// 测试用配置 - 请替换为您的服务器信息
static const String defaultWebDavUrl = 'https://your-server.com/dav';
static const String defaultUsername = 'your-username';
static const String defaultPassword = 'your-password';
```

### 支持的 WebDAV 服务器

- ✅ Nextcloud
- ✅ ownCloud
- ✅ Synology NAS
- ✅ 坚果云
- ✅ Apache mod_dav
- ✅ Nginx WebDAV 模块

## 🔍 常用调试命令

### 查看设备列表

```bash
flutter devices
```

### 查看应用日志

```bash
# 实时查看日志
flutter logs

# 查看特定设备日志
flutter logs -d <device-id>
```

### 性能分析

```bash
# 启用性能监控
flutter run --profile

# 分析应用性能
flutter analyze
```

### 依赖管理

```bash
# 查看依赖树
flutter pub deps

# 检查过期依赖
flutter pub outdated

# 升级依赖
flutter pub upgrade --major-versions
```

## 🐛 故障排除

### 常见错误快速修复

#### 构建失败

```bash
flutter clean
flutter pub get
flutter run
```

#### Gradle 错误 (Android)

```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
```

#### iOS 构建错误

```bash
cd ios
rm -rf Pods
rm Podfile.lock
pod install
cd ..
flutter clean
flutter run -d ios
```

#### 权限错误

确保在 `AndroidManifest.xml` 和 `Info.plist` 中配置了正确的权限。

### 获取帮助

- 查看错误日志: `flutter logs`
- 分析代码: `flutter analyze`
- 检查环境: `flutter doctor -v`

## 📊 性能优化技巧

### 开发时

- 使用 `--profile` 模式测试性能
- 开启 `flutter run --trace-startup` 分析启动性能

### 构建时

```bash
# 启用代码混淆和优化
flutter build apk --release --obfuscate --split-debug-info=build/debug-info

# 分析包体积
flutter build apk --analyze-size
```

## 🎯 下一步

1. **熟悉代码结构**: 查看 `lib/` 目录下的文件组织
2. **运行测试**: `flutter test`
3. **阅读开发文档**: 查看 `DEVELOPMENT.md`
4. **配置您的 WebDAV 服务器**: 修改 `app_constants.dart`
5. **开始开发**: 享受 Flutter 开发的乐趣！

---

🎉 **恭喜！** 您已经成功运行了 DAV Nexus 应用。如果遇到任何问题，请查看详细的开发文档或提交 Issue。
