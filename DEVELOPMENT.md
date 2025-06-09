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

## 开发指南

### 代码规范

- 遵循 [Dart 官方代码规范](https://dart.dev/guides/language/effective-dart)
- 使用 `flutter analyze` 检查代码质量
- 使用 `dart format` 格式化代码

### 测试策略

#### 单元测试

- Model 类测试
- Service 层测试
- Provider 状态测试

#### UI 测试

- Widget 测试
- 页面导航测试
- 用户交互测试

## 安全考虑

### 数据加密

- 使用 HTTPS 传输
- 敏感数据本地加密存储
- 实现安全的密码存储

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

---

📚 **技术支持**: 如需更多技术支持，请查看代码注释或联系开发团队。
