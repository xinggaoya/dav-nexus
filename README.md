# DAV Nexus - 专业的 WebDAV 云盘应用

专业的 WebDAV 云盘应用，基于 Flutter 开发，支持多平台，提供文件管理和智能相册同步功能

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

## 快速开始

### 1. 克隆项目

```bash
git clone https://github.com/xinggaoya/dav-nexus.git
cd dav-nexus
```

### 2. 安装依赖

```bash
flutter pub get
```

### 3. 运行应用

```bash
# Android
flutter run -d android

# iOS (仅 macOS)
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

## 文档

- [开发文档](DEVELOPMENT.md) - 详细的技术文档和 API 说明
- [快速开始指南](QUICKSTART.md) - 详细的环境配置和运行指南
- [更新日志](CHANGELOG.md) - 版本历史和功能变更

## 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 联系方式

- **项目维护者**: [xinggaoya](https://github.com/xinggaoya)
- **邮箱**: xinggaoya@qq.com
- **问题反馈**: [GitHub Issues](https://github.com/xinggaoya/dav-nexus/issues)

---

📱 **Happy Coding!** 希望这个项目对您有帮助。如果您有任何问题或建议，请随时联系我们。
