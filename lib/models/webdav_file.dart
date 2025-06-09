import 'package:intl/intl.dart';
import 'package:filesize/filesize.dart';

/// WebDAV文件/文件夹模型
class WebDavFile {
  final String name;
  final String path;
  final bool isDirectory;
  final int size;
  final DateTime? lastModified;
  final String? contentType;
  final String? etag;

  WebDavFile({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.size = 0,
    this.lastModified,
    this.contentType,
    this.etag,
  });

  /// 从WebDAV响应创建文件对象
  factory WebDavFile.fromWebDavResponse(Map<String, dynamic> response) {
    final href = response['href'] as String? ?? '';
    final propStat = response['propstat'] as Map<String, dynamic>? ?? {};
    final prop = propStat['prop'] as Map<String, dynamic>? ?? {};

    // 解析文件名
    String name = Uri.decodeFull(href.split('/').last);
    if (name.isEmpty && href.endsWith('/')) {
      final parts = href.split('/');
      name = parts[parts.length - 2];
    }

    // 解析文件大小
    final contentLengthStr = prop['getcontentlength'] as String?;
    int size = 0;
    if (contentLengthStr != null) {
      size = int.tryParse(contentLengthStr) ?? 0;
    }

    // 解析修改时间
    DateTime? lastModified;
    final lastModifiedStr = prop['getlastmodified'] as String?;
    if (lastModifiedStr != null) {
      try {
        lastModified = DateTime.parse(lastModifiedStr);
      } catch (e) {
        // 忽略解析错误
      }
    }

    // 判断是否为目录
    final resourceType = prop['resourcetype'] as Map<String, dynamic>?;
    final isDirectory = resourceType?.containsKey('collection') ?? false;

    return WebDavFile(
      name: name,
      path: href,
      isDirectory: isDirectory,
      size: size,
      lastModified: lastModified,
      contentType: prop['getcontenttype'] as String?,
      etag: prop['getetag'] as String?,
    );
  }

  /// 获取文件扩展名
  String get extension {
    if (isDirectory) return 'folder';
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex == -1) return '';
    return name.substring(dotIndex + 1).toLowerCase();
  }

  /// 获取格式化的文件大小
  String get formattedSize {
    if (isDirectory) return '';
    return filesize(size);
  }

  /// 获取格式化的修改时间
  String get formattedDate {
    if (lastModified == null) return '';
    final now = DateTime.now();
    final difference = now.difference(lastModified!);

    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(lastModified!);
    } else if (difference.inDays < 7) {
      return DateFormat('E HH:mm').format(lastModified!);
    } else if (lastModified!.year == now.year) {
      return DateFormat('MM-dd HH:mm').format(lastModified!);
    } else {
      return DateFormat('yyyy-MM-dd').format(lastModified!);
    }
  }

  /// 获取父目录路径
  String get parentPath {
    if (path == '/' || path == '/dav' || path == '/dav/') return path;

    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.length <= 1) return '/';

    // 移除最后一个段（文件名或目录名）
    segments.removeLast();

    if (segments.isEmpty) {
      return '/';
    }

    // 重新构建路径
    final result = '/${segments.join('/')}/';
    print('parentPath calculation: $path -> $result'); // 调试日志
    return result;
  }

  @override
  String toString() {
    return 'WebDavFile{name: $name, path: $path, isDirectory: $isDirectory, size: $size}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WebDavFile &&
          runtimeType == other.runtimeType &&
          path == other.path;

  @override
  int get hashCode => path.hashCode;
}
