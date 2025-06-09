import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/webdav_file.dart';
import '../constants/app_theme.dart';

/// 文件缩略图组件
class FileThumbnail extends StatelessWidget {
  final WebDavFile file;
  final double size;
  final String? authHeader;
  final String? baseUrl;

  const FileThumbnail({
    super.key,
    required this.file,
    this.size = 48,
    this.authHeader,
    this.baseUrl,
  });

  @override
  Widget build(BuildContext context) {
    if (file.isDirectory) {
      return Icon(Icons.folder, size: size, color: AppTheme.primaryColor);
    }

    // 检查是否为图片文件
    if (_isImageFile(file)) {
      return _buildImageThumbnail();
    }

    // 其他文件类型显示图标
    return Icon(_getFileIcon(file), size: size, color: AppTheme.textSecondary);
  }

  /// 构建图片缩略图
  Widget _buildImageThumbnail() {
    // 构建完整的图片URL
    String imageUrl = _buildImageUrl();

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        httpHeaders: authHeader != null ? {'Authorization': authHeader!} : null,
        placeholder: (context, url) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.image, size: size * 0.5, color: Colors.grey[400]),
        ),
        errorWidget: (context, url, error) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.broken_image,
            size: size * 0.5,
            color: Colors.grey[400],
          ),
        ),
      ),
    );
  }

  /// 构建图片URL
  String _buildImageUrl() {
    if (baseUrl == null) {
      return file.path;
    }

    // 确保基础URL正确格式化
    String formattedBaseUrl = baseUrl!;
    if (!formattedBaseUrl.endsWith('/')) {
      formattedBaseUrl += '/';
    }

    // 处理文件路径
    String filePath = file.path;

    // 检查路径是否已经包含/dav/前缀
    if (filePath.startsWith('/dav/')) {
      // 如果路径已经包含/dav/，则组合域名部分
      final uri = Uri.parse(formattedBaseUrl);
      return '${uri.scheme}://${uri.host}${filePath}';
    }

    // 移除路径开头的斜杠，因为基础URL已经以斜杠结尾
    if (filePath.startsWith('/')) {
      filePath = filePath.substring(1);
    }

    return '$formattedBaseUrl$filePath';
  }

  /// 检查是否为图片文件
  bool _isImageFile(WebDavFile file) {
    final extension = file.extension.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(extension);
  }

  /// 获取文件图标
  IconData _getFileIcon(WebDavFile file) {
    switch (file.extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
      case 'webp':
        return Icons.image;
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'mkv':
      case 'flv':
      case 'wmv':
        return Icons.video_file;
      case 'mp3':
      case 'wav':
      case 'flac':
      case 'aac':
      case 'm4a':
        return Icons.audio_file;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'txt':
      case 'md':
        return Icons.text_snippet;
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
      case 'gz':
        return Icons.archive;
      case 'exe':
      case 'msi':
        return Icons.apps;
      case 'html':
      case 'htm':
        return Icons.web;
      case 'json':
      case 'xml':
      case 'yml':
      case 'yaml':
        return Icons.code;
      default:
        return Icons.insert_drive_file;
    }
  }
}
