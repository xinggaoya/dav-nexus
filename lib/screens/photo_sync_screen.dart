import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:filesize/filesize.dart';

import '../providers/auth_provider.dart';
import '../services/photo_sync_service.dart';
import '../services/sync_database_service.dart';
import '../models/photo_sync_record.dart';
import '../constants/app_theme.dart';
import '../constants/app_constants.dart';

/// 相册同步界面
class PhotoSyncScreen extends StatefulWidget {
  const PhotoSyncScreen({super.key});

  @override
  State<PhotoSyncScreen> createState() => _PhotoSyncScreenState();
}

class _PhotoSyncScreenState extends State<PhotoSyncScreen> {
  late PhotoSyncService _syncService;
  SyncStatistics? _statistics;
  List<PhotoSyncRecord> _recentRecords = [];

  @override
  void initState() {
    super.initState();
    _syncService = PhotoSyncService();
    _initializeService();
  }

  @override
  void dispose() {
    _syncService.dispose();
    super.dispose();
  }

  /// 初始化服务
  Future<void> _initializeService() async {
    final success = await _syncService.initialize();
    if (success) {
      await _loadStatistics();
      await _loadRecentRecords();
    }
  }

  /// 加载统计信息
  Future<void> _loadStatistics() async {
    final stats = await _syncService.getStatistics();
    setState(() {
      _statistics = stats;
    });
  }

  /// 加载最近的同步记录
  Future<void> _loadRecentRecords() async {
    final records = await SyncDatabaseService.getAllRecords();
    setState(() {
      _recentRecords = records.take(20).toList(); // 只显示最近20条
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('相册同步'),
        actions: [
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'reset',
                child: ListTile(
                  leading: Icon(Icons.refresh),
                  title: Text('重置同步记录'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'cleanup',
                child: ListTile(
                  leading: Icon(Icons.cleaning_services),
                  title: Text('清理失败记录'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: ChangeNotifierProvider.value(
        value: _syncService,
        child: Column(
          children: [
            _buildSyncControlPanel(),
            _buildStatisticsPanel(),
            const Divider(),
            Expanded(child: _buildRecordsList()),
          ],
        ),
      ),
    );
  }

  /// 构建同步控制面板
  Widget _buildSyncControlPanel() {
    return Consumer<PhotoSyncService>(
      builder: (context, syncService, child) {
        return Container(
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.paddingMedium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.photo_library,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '相册同步',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (syncService.isSyncing)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 当前状态
                  if (syncService.errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error, color: AppTheme.errorColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              syncService.errorMessage!,
                              style: const TextStyle(
                                color: AppTheme.errorColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (syncService.isScanning)
                    const Text('正在扫描本地相册...')
                  else if (syncService.isSyncing)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '正在同步... ${syncService.processedFiles}/${syncService.totalFiles}',
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(value: syncService.progress),
                        if (syncService.currentUploading != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '当前上传: ${syncService.currentUploading!.fileName}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                      ],
                    )
                  else
                    const Text('准备就绪'),

                  const SizedBox(height: 16),

                  // 操作按钮
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed:
                              syncService.isScanning || syncService.isSyncing
                              ? null
                              : _scanPhotos,
                          icon: const Icon(Icons.search),
                          label: const Text('扫描相册'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: syncService.isScanning
                              ? null
                              : syncService.isSyncing
                              ? _stopSync
                              : _startSync,
                          icon: Icon(
                            syncService.isSyncing ? Icons.stop : Icons.sync,
                          ),
                          label: Text(syncService.isSyncing ? '停止同步' : '开始同步'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: syncService.isSyncing
                                ? AppTheme.errorColor
                                : AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (syncService.totalFiles > 0 && !syncService.isSyncing)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _retryFailed,
                              icon: const Icon(Icons.refresh),
                              label: const Text('重试失败'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 构建统计信息面板
  Widget _buildStatisticsPanel() {
    if (_statistics == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingMedium,
      ),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '同步统计',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // 进度条
              if (_statistics!.totalCount > 0) ...[
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: _statistics!.progress,
                        backgroundColor: Colors.grey[300],
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(_statistics!.progressPercent),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // 统计数字
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      '总计',
                      _statistics!.totalCount.toString(),
                      Colors.blue,
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      '已完成',
                      _statistics!.completedCount.toString(),
                      Colors.green,
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      '跳过',
                      _statistics!.skippedCount.toString(),
                      Colors.grey,
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      '失败',
                      _statistics!.failedCount.toString(),
                      Colors.red,
                    ),
                  ),
                ],
              ),

              if (_statistics!.totalSize > 0) ...[
                const SizedBox(height: 12),
                Text(
                  '总大小: ${filesize(_statistics!.totalSize)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 构建统计项目
  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  /// 构建记录列表
  Widget _buildRecordsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(AppConstants.paddingMedium),
          child: Text(
            '最近同步记录',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: _recentRecords.isEmpty
              ? const Center(child: Text('暂无同步记录'))
              : ListView.builder(
                  itemCount: _recentRecords.length,
                  itemBuilder: (context, index) {
                    final record = _recentRecords[index];
                    return _buildRecordItem(record);
                  },
                ),
        ),
      ],
    );
  }

  /// 构建单个记录项
  Widget _buildRecordItem(PhotoSyncRecord record) {
    Color statusColor;
    IconData statusIcon;

    switch (record.status) {
      case SyncStatus.completed:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case SyncStatus.failed:
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      case SyncStatus.pending:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
      case SyncStatus.uploading:
        statusColor = Colors.blue;
        statusIcon = Icons.upload;
        break;
      case SyncStatus.skipped:
        statusColor = Colors.grey;
        statusIcon = Icons.skip_next;
        break;
    }

    return ListTile(
      leading: Icon(statusIcon, color: statusColor),
      title: Text(record.fileName, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${record.status.displayName} • ${filesize(record.fileSize)}',
            style: const TextStyle(fontSize: 12),
          ),
          if (record.errorMessage != null)
            Text(
              record.errorMessage!,
              style: const TextStyle(fontSize: 11, color: Colors.red),
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      trailing: record.lastSyncTime != null
          ? Text(
              '${record.lastSyncTime!.month}/${record.lastSyncTime!.day} '
              '${record.lastSyncTime!.hour.toString().padLeft(2, '0')}:'
              '${record.lastSyncTime!.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            )
          : null,
    );
  }

  /// 扫描相册
  Future<void> _scanPhotos() async {
    await _syncService.scanLocalPhotos();
    await _loadStatistics();
    await _loadRecentRecords();
  }

  /// 开始同步
  Future<void> _startSync() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.webDavService != null) {
      await _syncService.startSync(authProvider.webDavService!);
      await _loadStatistics();
      await _loadRecentRecords();
    }
  }

  /// 停止同步
  void _stopSync() {
    _syncService.stopSync();
  }

  /// 重试失败的上传
  Future<void> _retryFailed() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.webDavService != null) {
      await _syncService.retryFailedUploads(authProvider.webDavService!);
      await _loadStatistics();
      await _loadRecentRecords();
    }
  }

  /// 处理菜单操作
  Future<void> _handleMenuAction(String action) async {
    switch (action) {
      case 'reset':
        await _confirmReset();
        break;
      case 'cleanup':
        await _cleanupFailed();
        break;
    }
  }

  /// 确认重置
  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重置同步记录'),
        content: const Text('这将清空所有同步记录，下次同步时会重新扫描所有照片。确定要继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('重置'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _syncService.resetSyncRecords();
      await _loadStatistics();
      await _loadRecentRecords();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('同步记录已重置')));
      }
    }
  }

  /// 清理失败记录
  Future<void> _cleanupFailed() async {
    await _syncService.cleanupFailedRecords();
    await _loadStatistics();
    await _loadRecentRecords();

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('失败记录已清理')));
    }
  }
}
