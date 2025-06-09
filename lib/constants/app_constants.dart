/// WebDAV云盘应用常量配置
class AppConstants {
  // WebDAV服务器配置
  // static const String defaultWebDavUrl = 'https://yun.moncn.cn/dav';
  // static const String defaultUsername = 'xinggaoya@qq.com';
  // static const String defaultPassword = 'HPmwOfv0ruFSr0RLpH5Gri4yniSFtMer';

  // 本地存储键
  static const String keyIsLoggedIn = 'is_logged_in';
  static const String keyWebDavUrl = 'webdav_url';
  static const String keyUsername = 'username';
  static const String keyPassword = 'password';
  static const String keyRememberCredentials = 'remember_credentials';

  // 应用配置
  static const String appName = 'DAV Nexus';
  static const String appVersion = '1.0.0';

  // 文件类型图标映射
  static const Map<String, String> fileTypeIcons = {
    'folder': 'folder',
    'pdf': 'picture_as_pdf',
    'doc': 'description',
    'docx': 'description',
    'txt': 'description',
    'jpg': 'image',
    'jpeg': 'image',
    'png': 'image',
    'gif': 'image',
    'mp4': 'video_file',
    'avi': 'video_file',
    'mp3': 'audio_file',
    'wav': 'audio_file',
    'zip': 'archive',
    'rar': 'archive',
    '7z': 'archive',
    'default': 'insert_drive_file',
  };

  // UI配置
  static const double borderRadius = 12.0;
  static const double cardElevation = 2.0;
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
}
