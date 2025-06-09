import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:filesize/filesize.dart';

import '../providers/auth_provider.dart';
import '../providers/app_settings_provider.dart'; // 添加设置提供者
import '../services/photo_sync_service.dart';
import '../services/sync_database_service.dart';
import '../services/webdav_service.dart';
import '../services/notification_service.dart'; // 添加通知服务
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
  LocalPhotoStatistics? _localStatistics; // 添加本地统计
  List<PhotoSyncRecord> _recentRecords = [];
  bool _isLoadingRecords = false;
  bool _isLoadingLocalStats = false; // 添加本地统计加载状态
  int _recordsPage = 0;
  final int _recordsPageSize = 50; // 分页加载记录
  bool _hasMoreRecords = true;
  int _totalRecordsCount = 0; // 添加总记录数
  final ScrollController _scrollController = ScrollController();

  // 添加筛选状态
  SyncStatus? _filterStatus;
  final List<SyncStatus> _availableStatuses = SyncStatus.values;

  @override
  void initState() {
    super.initState();
    _syncService = PhotoSyncService();
    _initializeService();
    _setupScrollListener();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _syncService.dispose();
    super.dispose();
  }

  /// 设置滚动监听器
  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
              _scrollController.position.maxScrollExtent &&
          !_isLoadingRecords &&
          _hasMoreRecords) {
        _loadMoreRecords();
      }
    });
  }

  /// 初始化服务
  Future<void> _initializeService() async {
    // 集成应用设置
    final appSettings = Provider.of<AppSettingsProvider>(
      context,
      listen: false,
    );
    _syncService.setAppSettings(appSettings);

    // 初始化通知服务
    await NotificationService.initialize();

    final success = await _syncService.initialize();
    if (success) {
      await _loadStatistics();
      await _loadLocalStatistics(); // 加载本地统计
      await _loadRecentRecords();
    }
  }

  /// 加载统计信息
  Future<void> _loadStatistics() async {
    final stats = await _syncService.getStatistics();
    if (mounted) {
      setState(() {
        _statistics = stats;
      });
    }
  }

  /// 加载本地相册统计信息
  Future<void> _loadLocalStatistics() async {
    setState(() {
      _isLoadingLocalStats = true;
    });

    try {
      final localStats = await _syncService.getLocalPhotoStatistics();
      if (mounted) {
        setState(() {
          _localStatistics = localStats;
          _isLoadingLocalStats = false;
        });
      }
    } catch (e) {
      print('加载本地统计失败: $e');
      if (mounted) {
        setState(() {
          _isLoadingLocalStats = false;
        });
      }
    }
  }

  /// 加载最近的同步记录
  Future<void> _loadRecentRecords() async {
    // 首先获取总记录数
    final totalCount = await SyncDatabaseService.getTotalRecordsCount(
      filterStatus: _filterStatus,
    );

    setState(() {
      _recordsPage = 0;
      _recentRecords.clear();
      _totalRecordsCount = totalCount;
      _hasMoreRecords = totalCount > 0;
      _isLoadingRecords = false; // 重置加载状态
    });

    // 如果有记录才开始加载
    if (totalCount > 0) {
      await _loadMoreRecords();
    }
  }

  /// 加载更多记录
  Future<void> _loadMoreRecords() async {
    if (_isLoadingRecords || !_hasMoreRecords) return;

    setState(() {
      _isLoadingRecords = true;
    });

    try {
      final records = await SyncDatabaseService.getRecordsPaged(
        page: _recordsPage,
        pageSize: _recordsPageSize,
        filterStatus: _filterStatus,
      );

      if (mounted) {
        setState(() {
          _recentRecords.addAll(records);
          _recordsPage++;
          // 检查是否还有更多记录
          _hasMoreRecords =
              records.length == _recordsPageSize &&
              _recentRecords.length < _totalRecordsCount;
          _isLoadingRecords = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingRecords = false;
        });
      }
      print('加载记录失败: $e');
    }
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

  /// 取消当前操作
  void _cancelCurrentOperation() {
    _syncService.cancelCurrentOperation();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('操作已取消')));
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
                      if (syncService.isProcessing)
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
                  else if (syncService.isProcessing)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              syncService.isPaused
                                  ? Icons.pause_circle
                                  : Icons.sync,
                              size: 16,
                              color: syncService.isPaused
                                  ? Colors.orange
                                  : AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              syncService.isPaused
                                  ? '已暂停 - ${syncService.processedFiles}/${syncService.totalFiles}'
                                  : '正在处理 - ${syncService.processedFiles}/${syncService.totalFiles}',
                            ),
                            const Spacer(),
                            Text(
                              syncService.progressPercent,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '上传: ${syncService.uploadedFiles} | 跳过: ${syncService.skippedFiles} | 失败: ${syncService.failedFiles}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: syncService.progress,
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            syncService.isPaused
                                ? Colors.orange
                                : AppTheme.primaryColor,
                          ),
                        ),
                        if (syncService.currentUploading != null &&
                            !syncService.isPaused)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '当前处理: ${syncService.currentUploading!.fileName}',
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (syncService.isPaused)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              '处理已暂停，点击恢复按钮继续',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                      ],
                    )
                  else
                    const Text('准备就绪 - 点击开始直接处理和上传'),

                  const SizedBox(height: 16),

                  // 操作按钮 - 添加暂停/恢复功能
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: syncService.isProcessing
                              ? null
                              : _startProcessingAndSync,
                          icon: Icon(
                            syncService.isProcessing
                                ? Icons.sync
                                : Icons.cloud_upload,
                          ),
                          label: Text(
                            syncService.isProcessing ? '处理中...' : '开始处理和上传',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      // 添加暂停/恢复和取消按钮
                      if (syncService.isProcessing) ...[
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: syncService.isPaused
                              ? () => syncService.resumeProcessing()
                              : () => syncService.pauseProcessing(),
                          icon: Icon(
                            syncService.isPaused
                                ? Icons.play_arrow
                                : Icons.pause,
                          ),
                          label: Text(syncService.isPaused ? '恢复' : '暂停'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: syncService.isPaused
                                ? Colors.green
                                : Colors.orange,
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _cancelCurrentOperation,
                          icon: const Icon(Icons.stop),
                          label: const Text('停止'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.errorColor,
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  if (syncService.totalFiles > 0 && !syncService.isProcessing)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _retryFailed,
                              icon: const Icon(Icons.refresh),
                              label: const Text('重试失败文件'),
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
    return Consumer<PhotoSyncService>(
      builder: (context, syncService, child) {
        // 显示当前处理的实时统计，如果没有则显示数据库统计
        final showRealTimeStats =
            syncService.isProcessing || syncService.totalFiles > 0;

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
                  Row(
                    children: [
                      const Text(
                        '统计信息',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (showRealTimeStats)
                        Text(
                          '实时统计',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.blue,
                          ),
                        )
                      else if (_isLoadingLocalStats)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 本地相册统计（始终显示）
                  if (_localStatistics != null && !showRealTimeStats) ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.photo_library,
                          size: 16,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '本地相册统计',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatItem(
                            '图片',
                            _localStatistics!.totalPhotos.toString(),
                            Colors.green,
                          ),
                        ),
                        Expanded(
                          child: _buildStatItem(
                            '视频',
                            _localStatistics!.totalVideos.toString(),
                            Colors.purple,
                          ),
                        ),
                        Expanded(
                          child: _buildStatItem(
                            '总文件',
                            _localStatistics!.totalFiles.toString(),
                            Colors.blue,
                          ),
                        ),
                        Expanded(
                          child: _buildStatItem(
                            '估算大小',
                            filesize(_localStatistics!.estimatedSize),
                            Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 同步统计
                  if (showRealTimeStats) ...[
                    // 显示当前处理的实时统计
                    Row(
                      children: [
                        const Icon(
                          Icons.sync,
                          size: 16,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '同步进度',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (syncService.totalFiles > 0) ...[
                      Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(
                              value: syncService.progress,
                              backgroundColor: Colors.grey[300],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                syncService.isPaused
                                    ? Colors.orange
                                    : AppTheme.primaryColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            syncService.progressPercent,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],

                    // 实时统计数字
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatItem(
                            '文件总数',
                            syncService.totalFiles.toString(),
                            Colors.blue,
                          ),
                        ),
                        Expanded(
                          child: _buildStatItem(
                            '已处理',
                            syncService.processedFiles.toString(),
                            AppTheme.primaryColor,
                          ),
                        ),
                        Expanded(
                          child: _buildStatItem(
                            '成功上传',
                            syncService.uploadedFiles.toString(),
                            Colors.green,
                          ),
                        ),
                        Expanded(
                          child: _buildStatItem(
                            '跳过',
                            syncService.skippedFiles.toString(),
                            Colors.grey,
                          ),
                        ),
                        Expanded(
                          child: _buildStatItem(
                            '失败',
                            syncService.failedFiles.toString(),
                            Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ] else if (_statistics != null &&
                      _statistics!.totalCount > 0) ...[
                    // 显示历史同步统计（从数据库）
                    Row(
                      children: [
                        const Icon(
                          Icons.cloud_done,
                          size: 16,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '同步记录统计',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

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
                  ] else if (!_isLoadingLocalStats) ...[
                    const Center(
                      child: Text(
                        '暂无统计数据',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
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

  /// 构建记录列表（使用虚拟化列表）
  Widget _buildRecordsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
          child: Row(
            children: [
              const Text(
                '同步记录',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '共 $_totalRecordsCount 条记录',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),

        // 状态筛选器
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingMedium,
          ),
          child: Row(
            children: [
              const Text(
                '筛选:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _availableStatuses.length + 1, // +1 for "全部"
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      // "全部" 选项
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: const Text('全部'),
                          selected: _filterStatus == null,
                          onSelected: (selected) {
                            setState(() {
                              _filterStatus = null;
                              _loadRecentRecords();
                            });
                          },
                        ),
                      );
                    }

                    final status = _availableStatuses[index - 1];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(status.displayName),
                        selected: _filterStatus == status,
                        onSelected: (selected) {
                          setState(() {
                            _filterStatus = selected ? status : null;
                            _loadRecentRecords();
                          });
                        },
                        avatar: Icon(
                          _getStatusIcon(status),
                          size: 16,
                          color: _getStatusColor(status),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: _totalRecordsCount == 0 && !_isLoadingRecords
              ? const Center(child: Text('暂无同步记录'))
              : ListView.builder(
                  controller: _scrollController,
                  itemCount: _recentRecords.length + (_hasMoreRecords ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _recentRecords.length) {
                      // 加载更多的指示器（只有当有更多记录时才显示）
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    final record = _recentRecords[index];
                    return _buildRecordItem(record);
                  },
                ),
        ),
      ],
    );
  }

  /// 获取状态图标
  IconData _getStatusIcon(SyncStatus status) {
    switch (status) {
      case SyncStatus.completed:
        return Icons.check_circle;
      case SyncStatus.failed:
        return Icons.error;
      case SyncStatus.pending:
        return Icons.pending;
      case SyncStatus.uploading:
        return Icons.upload;
      case SyncStatus.skipped:
        return Icons.skip_next;
    }
  }

  /// 获取状态颜色
  Color _getStatusColor(SyncStatus status) {
    switch (status) {
      case SyncStatus.completed:
        return Colors.green;
      case SyncStatus.failed:
        return Colors.red;
      case SyncStatus.pending:
        return Colors.orange;
      case SyncStatus.uploading:
        return Colors.blue;
      case SyncStatus.skipped:
        return Colors.grey;
    }
  }

  /// 构建单个记录项
  Widget _buildRecordItem(PhotoSyncRecord record) {
    Color statusColor;
    IconData statusIcon;
    String statusDescription;

    switch (record.status) {
      case SyncStatus.completed:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusDescription = '同步成功';
        break;
      case SyncStatus.failed:
        statusColor = Colors.red;
        statusIcon = Icons.error;
        statusDescription = '同步失败';
        break;
      case SyncStatus.pending:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        statusDescription = '等待同步';
        break;
      case SyncStatus.uploading:
        statusColor = Colors.blue;
        statusIcon = Icons.upload;
        statusDescription = '正在上传';
        break;
      case SyncStatus.skipped:
        statusColor = Colors.grey;
        statusIcon = Icons.skip_next;
        statusDescription = '已跳过';
        break;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: ExpansionTile(
        leading: Icon(statusIcon, color: statusColor),
        title: Text(record.fileName, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    statusDescription,
                    style: TextStyle(
                      fontSize: 10,
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  filesize(record.fileSize),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            if (record.errorMessage != null) ...[
              const SizedBox(height: 4),
              Text(
                record.errorMessage!,
                style: const TextStyle(fontSize: 11, color: Colors.red),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ],
          ],
        ),
        trailing: record.lastSyncTime != null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${record.lastSyncTime!.month}/${record.lastSyncTime!.day}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  Text(
                    '${record.lastSyncTime!.hour.toString().padLeft(2, '0')}:'
                    '${record.lastSyncTime!.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              )
            : null,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('文件名', record.fileName),
                _buildDetailRow('本地路径', record.localPath),
                _buildDetailRow('远程路径', record.remotePath),
                _buildDetailRow('文件大小', filesize(record.fileSize)),
                _buildDetailRow(
                  '文件哈希',
                  record.fileHash.substring(0, 16) + '...',
                ),
                _buildDetailRow('创建时间', _formatDateTime(record.createdTime)),
                _buildDetailRow('修改时间', _formatDateTime(record.modifiedTime)),
                if (record.lastSyncTime != null)
                  _buildDetailRow(
                    '同步时间',
                    _formatDateTime(record.lastSyncTime!),
                  ),
                if (record.retryCount > 0)
                  _buildDetailRow('重试次数', record.retryCount.toString()),
                if (record.errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.error, size: 16, color: Colors.red),
                            SizedBox(width: 4),
                            Text(
                              '错误详情',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          record.errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
                if (record.status == SyncStatus.skipped) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info, size: 16, color: Colors.orange),
                            SizedBox(width: 4),
                            Text(
                              '跳过原因',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          '文件已存在于服务器或已成功同步过',
                          style: TextStyle(color: Colors.orange),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建详情行
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  /// 格式化日期时间
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// 开始流式处理和同步
  Future<void> _startProcessingAndSync() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final appSettings = Provider.of<AppSettingsProvider>(
      context,
      listen: false,
    );

    if (!authProvider.isLoggedIn) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先登录')));
      return;
    }

    // 检查自动同步设置
    if (!appSettings.autoSync && !appSettings.autoBackup) {
      final shouldContinue = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('提示'),
          content: const Text(
            '您未开启自动同步和自动备份功能。建议在设置中开启相关功能以获得更好的体验。\n\n是否继续手动同步？',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('继续'),
            ),
          ],
        ),
      );

      if (shouldContinue != true) return;
    }

    final webDavService = WebDavService(
      baseUrl: authProvider.webDavUrl,
      username: authProvider.username,
      password: authProvider.password,
    );

    await _syncService.startProcessingAndSync(webDavService);

    // 同步完成后刷新所有统计信息
    await _loadStatistics();
    await _loadLocalStatistics();
    await _loadRecentRecords();
  }

  /// 重试失败的文件
  Future<void> _retryFailed() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (!authProvider.isLoggedIn) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先登录')));
      return;
    }

    // 获取失败的记录
    final failedRecords = await SyncDatabaseService.getByStatus(
      SyncStatus.failed,
    );

    if (failedRecords.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('没有失败的记录需要重试')));
      return;
    }

    // 将失败记录重置为待处理状态
    for (final record in failedRecords) {
      await SyncDatabaseService.updateStatus(record.id, SyncStatus.pending);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已重置 ${failedRecords.length} 个失败记录，请重新开始同步')),
    );

    // 刷新记录列表
    await _loadRecentRecords();
  }

  /// 处理菜单操作
  Future<void> _handleMenuAction(String action) async {
    switch (action) {
      case 'reset':
        await _resetSyncRecords();
        break;
      case 'cleanup':
        await _cleanupFailedRecords();
        break;
    }
  }

  /// 重置同步记录
  Future<void> _resetSyncRecords() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认重置'),
        content: const Text('这将删除所有同步记录，重新开始同步。确定要继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await SyncDatabaseService.clearAllRecords();
      await _loadStatistics();
      await _loadLocalStatistics(); // 重新加载本地统计
      await _loadRecentRecords();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('同步记录已重置')));
    }
  }

  /// 清理失败记录
  Future<void> _cleanupFailedRecords() async {
    final failedRecords = await SyncDatabaseService.getByStatus(
      SyncStatus.failed,
    );

    if (failedRecords.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('没有失败记录需要清理')));
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清理'),
        content: Text('将删除 ${failedRecords.length} 条失败记录。确定要继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      for (final record in failedRecords) {
        await SyncDatabaseService.deleteRecord(record.id);
      }

      await _loadStatistics();
      await _loadLocalStatistics(); // 重新加载本地统计
      await _loadRecentRecords();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已清理 ${failedRecords.length} 条失败记录')),
      );
    }
  }
}
