# DAV Nexus 开发文档

## 架构概览

DAV Nexus 采用分层架构设计，确保代码的可维护性和可扩展性。

### 架构图

```
┌─────────────────┐
│   Presentation  │ ← Screens & Widgets
├─────────────────┤
│  State Management│ ← Providers (Consumer/Provider Pattern)
├─────────────────┤
│   Business Logic│ ← Services & Models
├─────────────────┤
│   Data Access   │ ← WebDAV API & Local Storage
└─────────────────┘
```

### 核心模块

#### 1. 认证模块 (Authentication)

- **AuthProvider**: 管理用户登录状态
- **WebDavService**: 处理 WebDAV 认证和连接测试
- **SharedPreferences**: 持久化用户凭据

#### 2. 文件管理模块 (File Management)

- **FileProvider**: 管理文件列表状态和操作
- **WebDavService**: 执行 WebDAV CRUD 操作
- **WebDavFile**: 文件数据模型

#### 3. 相册同步模块 (Photo Sync)

- **PhotoSyncService**: 处理相册同步逻辑
- **PhotoSyncRecord**: 同步记录数据模型
- **SyncDatabaseService**: 本地同步数据库

## 数据流

### 用户认证流程

```
LoginScreen → AuthProvider → WebDavService → Server Response → AuthProvider State Update → HomeScreen
```

### 文件操作流程

```
User Action → FileProvider → WebDavService → WebDAV Server → Response → FileProvider State Update → UI Update
```

### 相册同步流程

```
PhotoSyncScreen → PhotoSyncService → Photo Manager → Local Photos → WebDavService → Server Upload → Database Record
```

## API 文档

### WebDAV Service API

#### 连接测试

```dart
Future<bool> testConnection()
```

**功能**: 测试 WebDAV 服务器连接  
**返回值**: 连接成功返回 true，否则返回 false  
**异常**: 网络异常时抛出 Exception

#### 列出目录

```dart
Future<List<WebDavFile>> listDirectory(String path)
```

**参数**:

- `path`: 目录路径，根目录为"/"

**返回值**: WebDavFile 对象列表  
**异常**: 访问失败时抛出 Exception

#### 上传文件

```dart
Future<bool> uploadFile(String localPath, String remotePath, {Function(int, int)? onProgress})
```

**参数**:

- `localPath`: 本地文件路径
- `remotePath`: 远程保存路径
- `onProgress`: 进度回调函数(可选)

**返回值**: 上传成功返回 true

#### 下载文件

```dart
Future<Uint8List> downloadFile(String remotePath)
```

**参数**:

- `remotePath`: 远程文件路径

**返回值**: 文件二进制数据

#### 删除文件/文件夹

```dart
Future<bool> deleteFile(String remotePath)
```

#### 创建文件夹

```dart
Future<bool> createDirectory(String remotePath)
```

#### 重命名/移动

```dart
Future<bool> moveFile(String sourcePath, String destinationPath)
```

### Provider API

#### AuthProvider

**属性**:

```dart
bool isLoggedIn              // 登录状态
String? username             // 用户名
String? webDavUrl           // WebDAV服务器URL
WebDavService? webDavService // WebDAV服务实例
```

**方法**:

```dart
Future<bool> login(String url, String username, String password, bool remember)
Future<void> logout()
Future<void> loadSavedCredentials()
```

#### FileProvider

**属性**:

```dart
List<WebDavFile> files       // 当前目录文件列表
bool isLoading               // 加载状态
String? errorMessage         // 错误信息
String currentPath           // 当前路径
List<String> pathHistory     // 路径历史
FileViewType viewType        // 视图类型(列表/网格)
FileSortType sortType        // 排序类型
```

**方法**:

```dart
Future<void> loadDirectory(WebDavService service, [String? path])
Future<bool> uploadFile(WebDavService service, File file, [String? targetPath])
Future<bool> deleteFile(WebDavService service, WebDavFile file)
Future<bool> createDirectory(WebDavService service, String name)
Future<bool> renameFile(WebDavService service, WebDavFile file, String newName)
void navigateBack()
void changeViewType(FileViewType type)
void changeSortType(FileSortType type)
```

### Photo Sync Service API

#### 同步配置

```dart
class SyncConfig {
  bool autoSync;                    // 自动同步
  bool wifiOnly;                    // 仅WiFi同步
  bool includeVideos;               // 包含视频
  String remotePath;                // 远程存储路径
  int maxFileSize;                  // 最大文件大小(MB)
  bool createDateFolders;           // 按日期创建文件夹
}
```

#### 主要方法

```dart
Future<void> startSync()                           // 开始同步
Future<void> stopSync()                            // 停止同步
Future<List<PhotoSyncRecord>> getSyncHistory()     // 获取同步历史
Future<void> clearSyncHistory()                    // 清除同步历史
```

## 数据模型

### WebDavFile

```dart
class WebDavFile {
  final String name;           // 文件名
  final String path;           // 完整路径
  final bool isDirectory;      // 是否为目录
  final int size;              // 文件大小(字节)
  final DateTime? lastModified; // 最后修改时间
  final String? contentType;   // MIME类型
  final String? etag;          // ETag
}
```

### PhotoSyncRecord

```dart
class PhotoSyncRecord {
  final int? id;               // 记录ID
  final String localPath;      // 本地路径
  final String remotePath;     // 远程路径
  final int fileSize;          // 文件大小
  final String checksum;       // 文件校验和
  final DateTime syncTime;     // 同步时间
  final SyncStatus status;     // 同步状态
}
```

## 常量配置

### 应用常量 (AppConstants)

```dart
class AppConstants {
  // WebDAV默认配置
  static const String defaultWebDavUrl = '...';
  static const String defaultUsername = '...';
  static const String defaultPassword = '...';

  // 本地存储键名
  static const String keyIsLoggedIn = 'is_logged_in';
  static const String keyWebDavUrl = 'webdav_url';
  // ...

  // UI配置
  static const double borderRadius = 12.0;
  static const double cardElevation = 2.0;
  // ...
}
```

### 主题配置 (AppTheme)

支持亮色和暗色主题，使用 Material Design 3 规范。

## 错误处理

### 错误类型定义

```dart
enum ErrorType {
  networkError,      // 网络错误
  authenticationError, // 认证错误
  permissionError,   // 权限错误
  storageError,      // 存储错误
  unknownError,      // 未知错误
}
```

### 错误处理策略

1. **网络错误**: 显示重试按钮，支持离线模式
2. **认证错误**: 自动跳转到登录页面
3. **权限错误**: 引导用户到设置页面
4. **存储错误**: 清理缓存，释放空间

## 性能优化

### 内存管理

- 使用`ListView.builder`处理大列表
- 实现图片缓存机制
- 及时释放资源

### 网络优化

- 实现请求重试机制
- 支持断点续传
- 压缩上传文件

### 本地存储优化

- 使用 SQLite 索引
- 实现数据分页
- 定期清理过期数据

## 调试工具

### 日志系统

```dart
class Logger {
  static void info(String message) { /* ... */ }
  static void warning(String message) { /* ... */ }
  static void error(String message, [Object? error]) { /* ... */ }
}
```

### 性能监控

- 使用 Flutter Inspector
- 监控内存使用
- 网络请求性能分析

## 测试策略

### 单元测试

- Model 类测试
- Service 层测试
- Provider 状态测试

### 集成测试

- 登录流程测试
- 文件操作测试
- 相册同步测试

### UI 测试

- Widget 测试
- 页面导航测试
- 用户交互测试

### 测试用例示例

```dart
testWidgets('登录按钮点击测试', (WidgetTester tester) async {
  await tester.pumpWidget(MyApp());

  final loginButton = find.byType(ElevatedButton);
  expect(loginButton, findsOneWidget);

  await tester.tap(loginButton);
  await tester.pump();

  // 验证预期行为
});
```

## 安全考虑

### 数据加密

- 使用 HTTPS 传输
- 敏感数据本地加密存储
- 实现安全的密码存储

### 权限管理

- 最小权限原则
- 运行时权限检查
- 用户授权管理

### 代码混淆

```bash
# 发布构建时启用代码混淆
flutter build apk --release --obfuscate --split-debug-info=build/debug-info
```

## 国际化

### 支持语言

- 中文(简体)
- 英文
- 可扩展其他语言

### 实现方式

```dart
// 使用Flutter Intl插件
import 'package:flutter_localizations/flutter_localizations.dart';

MaterialApp(
  localizationsDelegates: [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: [
    Locale('zh', 'CN'),
    Locale('en', 'US'),
  ],
  // ...
)
```

## 发布流程

### Android 发布

1. 生成签名密钥
2. 配置 Gradle 构建
3. 构建发布 APK/AAB
4. 上传到 Google Play

### iOS 发布

1. 配置 Apple Developer 账号
2. 设置 Bundle ID 和证书
3. 构建 Archive
4. 上传到 App Store Connect

### Web 发布

1. 构建 Web 应用
2. 配置服务器
3. 部署到托管平台

## 维护指南

### 版本更新

- 遵循语义化版本号
- 维护 CHANGELOG.md
- 测试兼容性

### 依赖管理

```bash
# 检查过期依赖
flutter pub outdated

# 升级依赖
flutter pub upgrade

# 分析依赖大小
flutter pub deps
```

### 代码质量

```bash
# 代码分析
flutter analyze

# 格式化代码
dart format .

# 运行测试
flutter test
```

## 故障排除

### 常见问题解决方案

#### 1. WebDAV 连接失败

- 检查 URL 格式
- 验证证书问题
- 确认服务器配置

#### 2. 相册权限问题

- 检查清单文件权限
- 验证运行时权限
- 引导用户授权

#### 3. 构建失败

- 清理构建缓存
- 检查依赖冲突
- 更新 Flutter 版本

#### 4. 性能问题

- 使用 Profiler 分析
- 优化图片加载
- 减少重建频率

---

📚 **技术支持**: 如需更多技术支持，请查看代码注释或联系开发团队。
