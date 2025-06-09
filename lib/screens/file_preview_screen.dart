import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../models/webdav_file.dart';
import '../constants/app_theme.dart';
import '../constants/app_constants.dart';
import '../utils/file_utils.dart';

/// 文件预览界面
class FilePreviewScreen extends StatefulWidget {
  final WebDavFile file;
  final String? authHeader;
  final String? baseUrl;
  final VoidCallback? onDownload;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  const FilePreviewScreen({
    super.key,
    required this.file,
    this.authHeader,
    this.baseUrl,
    this.onDownload,
    this.onRename,
    this.onDelete,
  });

  @override
  State<FilePreviewScreen> createState() => _FilePreviewScreenState();
}

class _FilePreviewScreenState extends State<FilePreviewScreen> {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _showVideoControls = true;

  @override
  void initState() {
    super.initState();
    if (FileUtils.isVideoFile(widget.file)) {
      _initializeVideoPlayer();
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  /// 初始化视频播放器
  Future<void> _initializeVideoPlayer() async {
    try {
      final videoUrl = _buildFileUrl();
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
        httpHeaders: widget.authHeader != null
            ? {'Authorization': widget.authHeader!}
            : const <String, String>{},
      );

      await _videoController!.initialize();
      setState(() {
        _isVideoInitialized = true;
      });

      // 自动隐藏控制栏
      _startControlsTimer();
    } catch (e) {
      print('视频初始化失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('无法播放视频: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  /// 启动控制栏定时器
  void _startControlsTimer() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showVideoControls = false;
        });
      }
    });
  }

  /// 切换控制栏显示
  void _toggleVideoControls() {
    setState(() {
      _showVideoControls = !_showVideoControls;
    });

    if (_showVideoControls) {
      _startControlsTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(),
      body: _buildPreviewContent(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.black.withOpacity(0.8),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        widget.file.name,
        style: const TextStyle(color: Colors.white),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onPressed: _showMoreOptions,
        ),
      ],
    );
  }

  Widget _buildPreviewContent() {
    if (FileUtils.isImageFile(widget.file)) {
      return _buildImagePreview();
    } else if (FileUtils.isVideoFile(widget.file)) {
      return _buildVideoPreview();
    } else if (FileUtils.isTextFile(widget.file)) {
      return _buildTextPreview();
    } else {
      return _buildUnsupportedFilePreview();
    }
  }

  /// 构建图片预览
  Widget _buildImagePreview() {
    final imageUrl = _buildFileUrl();

    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 3.0,
      child: Center(
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          httpHeaders: widget.authHeader != null
              ? {'Authorization': widget.authHeader!}
              : null,
          fit: BoxFit.contain,
          placeholder: (context, url) => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
          errorWidget: (context, url, error) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.broken_image, size: 64, color: Colors.white54),
                const SizedBox(height: 16),
                Text(
                  '无法加载图片',
                  style: TextStyle(color: Colors.white54, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建视频预览
  Widget _buildVideoPreview() {
    if (!_isVideoInitialized || _videoController == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return GestureDetector(
      onTap: _toggleVideoControls,
      child: Stack(
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: VideoPlayer(_videoController!),
            ),
          ),
          if (_showVideoControls) _buildVideoControls(),
        ],
      ),
    );
  }

  /// 构建视频控制栏
  Widget _buildVideoControls() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.3),
            Colors.transparent,
            Colors.black.withOpacity(0.7),
          ],
        ),
      ),
      child: Column(
        children: [
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    _videoController!.value.isPlaying
                        ? Icons.pause
                        : Icons.play_arrow,
                    color: Colors.white,
                    size: 32,
                  ),
                  onPressed: () {
                    setState(() {
                      if (_videoController!.value.isPlaying) {
                        _videoController!.pause();
                      } else {
                        _videoController!.play();
                        _startControlsTimer();
                      }
                    });
                  },
                ),
                Expanded(
                  child: VideoProgressIndicator(
                    _videoController!,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(
                      playedColor: AppTheme.primaryColor,
                      bufferedColor: Colors.white30,
                      backgroundColor: Colors.white12,
                    ),
                  ),
                ),
                Text(
                  _formatDuration(_videoController!.value.position),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                const Text(
                  ' / ',
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
                Text(
                  _formatDuration(_videoController!.value.duration),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建文本预览
  Widget _buildTextPreview() {
    return Container(
      color: Colors.white,
      child: const Center(
        child: Text(
          '文本文件预览功能开发中...',
          style: TextStyle(color: Colors.black54, fontSize: 16),
        ),
      ),
    );
  }

  /// 构建不支持的文件预览
  Widget _buildUnsupportedFilePreview() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_getFileIcon(widget.file), size: 80, color: Colors.white54),
          const SizedBox(height: 24),
          Text(
            widget.file.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            widget.file.formattedSize,
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 32),
          const Text(
            '此文件类型不支持预览',
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: widget.onDownload,
            icon: const Icon(Icons.download),
            label: const Text('下载文件'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建底部操作栏
  Widget? _buildBottomBar() {
    if (!FileUtils.isPreviewableFile(widget.file)) {
      return null;
    }

    return Container(
      color: Colors.black.withOpacity(0.8),
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingMedium,
        vertical: AppConstants.paddingSmall,
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildBottomAction(
              icon: Icons.download,
              label: '下载',
              onTap: widget.onDownload,
            ),
            _buildBottomAction(
              icon: Icons.edit,
              label: '重命名',
              onTap: widget.onRename,
            ),
            _buildBottomAction(
              icon: Icons.delete,
              label: '删除',
              onTap: widget.onDelete,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomAction({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  /// 显示更多选项
  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.file.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppConstants.paddingMedium),
            ListTile(
              leading: const Icon(Icons.info, color: Colors.white),
              title: const Text('文件信息', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showFileInfo();
              },
            ),
            ListTile(
              leading: const Icon(Icons.download, color: Colors.white),
              title: const Text('下载', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                widget.onDownload?.call();
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.white),
              title: const Text('重命名', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                widget.onRename?.call();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('删除', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                widget.onDelete?.call();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 显示文件信息
  void _showFileInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('文件信息'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('文件名', widget.file.name),
            _buildInfoRow('大小', widget.file.formattedSize),
            _buildInfoRow('类型', widget.file.extension.toUpperCase()),
            if (widget.file.lastModified != null)
              _buildInfoRow('修改时间', widget.file.formattedDate),
            _buildInfoRow('路径', widget.file.path),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  /// 构建文件URL
  String _buildFileUrl() {
    if (widget.baseUrl == null) {
      return widget.file.path;
    }

    String formattedBaseUrl = widget.baseUrl!;
    if (!formattedBaseUrl.endsWith('/')) {
      formattedBaseUrl += '/';
    }

    String filePath = widget.file.path;
    if (filePath.startsWith('/dav/')) {
      final uri = Uri.parse(formattedBaseUrl);
      return '${uri.scheme}://${uri.host}${filePath}';
    }

    if (filePath.startsWith('/')) {
      filePath = filePath.substring(1);
    }

    return '$formattedBaseUrl$filePath';
  }

  /// 格式化视频时长
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    } else {
      return '${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
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
      case 'txt':
      case 'md':
        return Icons.text_snippet;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.archive;
      default:
        return Icons.insert_drive_file;
    }
  }
}
