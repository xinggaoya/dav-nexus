import '../models/webdav_file.dart';

/// 文件工具类
class FileUtils {
  /// 检查是否为图片文件
  static bool isImageFile(WebDavFile file) {
    final extension = file.extension.toLowerCase();
    const imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'];
    return imageExtensions.contains(extension);
  }

  /// 检查是否为视频文件
  static bool isVideoFile(WebDavFile file) {
    final extension = file.extension.toLowerCase();
    const videoExtensions = [
      'mp4',
      'avi',
      'mov',
      'mkv',
      'flv',
      'wmv',
      '3gp',
      'webm',
    ];
    return videoExtensions.contains(extension);
  }

  /// 检查是否为音频文件
  static bool isAudioFile(WebDavFile file) {
    final extension = file.extension.toLowerCase();
    const audioExtensions = ['mp3', 'wav', 'flac', 'aac', 'm4a', 'ogg'];
    return audioExtensions.contains(extension);
  }

  /// 检查是否为文本文件
  static bool isTextFile(WebDavFile file) {
    final extension = file.extension.toLowerCase();
    const textExtensions = [
      'txt',
      'md',
      'json',
      'xml',
      'html',
      'css',
      'js',
      'yaml',
      'yml',
      'csv',
      'log',
      'ini',
      'cfg',
      'conf',
      'properties',
    ];
    return textExtensions.contains(extension);
  }

  /// 检查是否为文档文件
  static bool isDocumentFile(WebDavFile file) {
    final extension = file.extension.toLowerCase();
    const documentExtensions = [
      'pdf',
      'doc',
      'docx',
      'xls',
      'xlsx',
      'ppt',
      'pptx',
      'rtf',
    ];
    return documentExtensions.contains(extension);
  }

  /// 检查是否为压缩文件
  static bool isArchiveFile(WebDavFile file) {
    final extension = file.extension.toLowerCase();
    const archiveExtensions = ['zip', 'rar', '7z', 'tar', 'gz', 'bz2', 'xz'];
    return archiveExtensions.contains(extension);
  }

  /// 检查是否为可预览文件
  static bool isPreviewableFile(WebDavFile file) {
    return isImageFile(file) || isVideoFile(file) || isTextFile(file);
  }

  /// 获取文件类型描述
  static String getFileTypeDescription(WebDavFile file) {
    if (isImageFile(file)) return '图片';
    if (isVideoFile(file)) return '视频';
    if (isAudioFile(file)) return '音频';
    if (isTextFile(file)) return '文本';
    if (isDocumentFile(file)) return '文档';
    if (isArchiveFile(file)) return '压缩包';
    return '文件';
  }

  /// 格式化文件大小
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// 检查文件名是否有效
  static bool isValidFileName(String fileName) {
    if (fileName.isEmpty) return false;

    // 检查是否包含非法字符
    const invalidChars = ['/', '\\', ':', '*', '?', '"', '<', '>', '|'];
    for (final char in invalidChars) {
      if (fileName.contains(char)) return false;
    }

    // 检查是否为保留名称（Windows）
    const reservedNames = [
      'CON',
      'PRN',
      'AUX',
      'NUL',
      'COM1',
      'COM2',
      'COM3',
      'COM4',
      'COM5',
      'COM6',
      'COM7',
      'COM8',
      'COM9',
      'LPT1',
      'LPT2',
      'LPT3',
      'LPT4',
      'LPT5',
      'LPT6',
      'LPT7',
      'LPT8',
      'LPT9',
    ];

    final nameWithoutExtension = fileName.contains('.')
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : fileName;

    return !reservedNames.contains(nameWithoutExtension.toUpperCase());
  }

  /// 获取安全的文件名（移除非法字符）
  static String getSafeFileName(String fileName) {
    String safeName = fileName;

    // 替换非法字符
    const invalidChars = ['/', '\\', ':', '*', '?', '"', '<', '>', '|'];
    for (final char in invalidChars) {
      safeName = safeName.replaceAll(char, '_');
    }

    // 如果是保留名称，添加后缀
    const reservedNames = [
      'CON',
      'PRN',
      'AUX',
      'NUL',
      'COM1',
      'COM2',
      'COM3',
      'COM4',
      'COM5',
      'COM6',
      'COM7',
      'COM8',
      'COM9',
      'LPT1',
      'LPT2',
      'LPT3',
      'LPT4',
      'LPT5',
      'LPT6',
      'LPT7',
      'LPT8',
      'LPT9',
    ];

    final nameWithoutExtension = safeName.contains('.')
        ? safeName.substring(0, safeName.lastIndexOf('.'))
        : safeName;

    if (reservedNames.contains(nameWithoutExtension.toUpperCase())) {
      if (safeName.contains('.')) {
        final extension = safeName.substring(safeName.lastIndexOf('.'));
        safeName = '${nameWithoutExtension}_file$extension';
      } else {
        safeName = '${safeName}_file';
      }
    }

    return safeName;
  }
}
