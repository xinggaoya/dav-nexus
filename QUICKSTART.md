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
# 1. 克隆项目
git clone https://github.com/xinggaoya/dav-nexus.git
cd dav-nexus

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

## 🏗️ 构建发布版本

### Android APK

```bash
# 构建发布APK
flutter build apk --release

# 分架构构建 (减小包体积)
flutter build apk --split-per-abi --release
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

## 🎯 下一步

1. **熟悉代码结构**: 查看 `lib/` 目录下的文件组织
2. **运行测试**: `flutter test`
3. **阅读开发文档**: 查看 `DEVELOPMENT.md`
4. **配置您的 WebDAV 服务器**: 修改 `app_constants.dart`
5. **开始开发**: 享受 Flutter 开发的乐趣！

---

🎉 **恭喜！** 您已经成功运行了 DAV Nexus 应用。如果遇到任何问题，请查看详细的开发文档或提交 Issue。
