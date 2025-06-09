import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as path;

import '../models/photo_sync_record.dart';
import '../services/sync_database_service.dart';
import '../services/webdav_service.dart';

/// 相册同步服务
class PhotoSyncService extends ChangeNotifier {
  static const String ALBUM_FOLDER_NAME = '相册';
  static const int BATCH_SIZE = 10; // 批量处理大小
  static const int MAX_RETRY_COUNT = 3; // 最大重试次数

  bool _isScanning = false;
  bool _isSyncing = false;
  bool _isInitialized = false;
  String? _errorMessage;

  int _totalFiles = 0;
  int _processedFiles = 0;
  int _uploadedFiles = 0;
  int _skippedFiles = 0;
  int _failedFiles = 0;

  PhotoSyncRecord? _currentUploading;

  // Getters
  bool get isScanning => _isScanning;
  bool get isSyncing => _isSyncing;
  bool get isInitialized => _isInitialized;
  String? get errorMessage => _errorMessage;
  int get totalFiles => _totalFiles;
  int get processedFiles => _processedFiles;
  int get uploadedFiles => _uploadedFiles;
  int get skippedFiles => _skippedFiles;
  int get failedFiles => _failedFiles;
  PhotoSyncRecord? get currentUploading => _currentUploading;

  double get progress {
    if (_totalFiles == 0) return 0.0;
    return _processedFiles / _totalFiles;
  }

  /// 初始化同步服务
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // 请求相册权限
      final hasPermission = await _requestPhotoPermission();
      if (!hasPermission) {
        _errorMessage = '没有相册访问权限';
        return false;
      }

      _isInitialized = true;
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = '初始化失败: $e';
      notifyListeners();
      return false;
    }
  }

  /// 请求相册权限
  Future<bool> _requestPhotoPermission() async {
    try {
      // 首先检查当前权限状态
      PermissionState ps = await PhotoManager.requestPermissionExtend();

      // 如果权限被拒绝，尝试使用 permission_handler 请求
      if (!ps.isAuth) {
        if (Platform.isAndroid) {
          // Android 需要根据系统版本请求不同权限
          final androidInfo = await _getAndroidVersion();

          bool granted = false;
          if (androidInfo >= 33) {
            // Android 13+ 使用新的媒体权限
            final results = await [
              Permission.photos,
              Permission.videos,
            ].request();
            granted = results.values.every((status) => status.isGranted);
          } else {
            // Android 12 及以下使用存储权限
            final status = await Permission.storage.request();
            granted = status.isGranted;
          }

          if (granted) {
            // 重新检查 PhotoManager 权限
            ps = await PhotoManager.requestPermissionExtend();
          }
        } else {
          // iOS 使用 photos 权限
          final status = await Permission.photos.request();
          if (status.isGranted) {
            ps = await PhotoManager.requestPermissionExtend();
          }
        }
      }

      return ps.isAuth;
    } catch (e) {
      print('权限请求失败: $e');
      return false;
    }
  }

  /// 获取 Android 版本
  Future<int> _getAndroidVersion() async {
    try {
      if (Platform.isAndroid) {
        // 简单的版本检测，可以根据需要扩展
        return 33; // 假设是较新版本
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  /// 扫描本地相册
  Future<void> scanLocalPhotos() async {
    if (_isScanning) return;

    _isScanning = true;
    _errorMessage = null;
    notifyListeners();

    try {
      print('开始扫描本地相册...');

      // 再次检查权限
      final hasPermission = await _requestPhotoPermission();
      if (!hasPermission) {
        _errorMessage = '没有相册访问权限，请在设置中允许访问相册';
        return;
      }

      print('权限检查通过，获取相册列表...');

      // 获取所有相册
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.common, // 包含图片和视频
        onlyAll: false,
      );

      print('找到 ${albums.length} 个相册');

      if (albums.isEmpty) {
        _errorMessage = '未找到任何相册，请确保设备中有照片或视频';
        return;
      }

      // 先获取总数进行内存估算
      int totalAssets = 0;
      for (final album in albums) {
        final assetCount = await album.assetCountAsync;
        totalAssets += assetCount;
      }

      print('总计 $totalAssets 个文件');

      // 如果文件数量过多，给出警告并限制处理数量
      const maxProcessFiles = 5000; // 最大处理文件数
      if (totalAssets > maxProcessFiles) {
        _errorMessage =
            '检测到 $totalAssets 个文件，为防止内存不足，本次将只处理前 $maxProcessFiles 个文件。建议分批次同步。';
        notifyListeners();
      }

      final List<PhotoSyncRecord> newRecords = [];
      int processedAssets = 0;

      // 遍历所有相册
      for (final album in albums) {
        if (processedAssets >= maxProcessFiles) {
          print('已达到最大处理数量限制，停止扫描');
          break;
        }

        print('处理相册: ${album.name}');

        final assetCount = await album.assetCountAsync;
        print('相册 ${album.name} 包含 $assetCount 个文件');

        if (assetCount == 0) continue;

        // 分页获取资源，避免一次性加载过多
        const pageSize = 50; // 减少页面大小以降低内存压力
        int page = 0;
        int albumProcessedCount = 0;

        while (true) {
          // 检查是否已达到总体限制
          if (processedAssets >= maxProcessFiles) {
            break;
          }

          final List<AssetEntity> assets = await album.getAssetListPaged(
            page: page,
            size: pageSize,
          );

          if (assets.isEmpty) break;

          print('处理第 ${page + 1} 页，${assets.length} 个文件');

          // 分批处理资源以避免内存压力
          const batchSize = 10;
          for (int i = 0; i < assets.length; i += batchSize) {
            if (processedAssets >= maxProcessFiles) break;

            final batch = assets.skip(i).take(batchSize).toList();
            await _processAssetBatch(batch, newRecords);

            processedAssets += batch.length;
            albumProcessedCount += batch.length;

            // 更新进度
            _processedFiles = processedAssets;
            notifyListeners();

            // 定期释放内存
            if (processedAssets % 100 == 0) {
              await Future.delayed(
                const Duration(milliseconds: 50),
              ); // 短暂暂停释放内存
            }
          }

          page++;

          // 限制最大页数，避免无限循环
          if (page > 100) {
            print('相册 ${album.name} 页数过多，跳过剩余部分');
            break;
          }
        }

        print('相册 ${album.name} 处理完成，处理了 $albumProcessedCount 个文件');
      }

      print('扫描完成，总计处理 $processedAssets 个文件，新增 ${newRecords.length} 个待同步文件');

      // 批量插入新记录
      if (newRecords.isNotEmpty) {
        await SyncDatabaseService.insertBatch(newRecords);
        print('已保存 ${newRecords.length} 条新记录到数据库');
      }

      _totalFiles = newRecords.length;
      _processedFiles = processedAssets;

      if (newRecords.isEmpty && processedAssets > 0) {
        _errorMessage = '所有已扫描的文件都已存在记录，没有新文件需要同步';
      }
    } catch (e) {
      print('扫描相册失败: $e');
      _errorMessage = '扫描相册失败: $e';
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  /// 分批处理资源
  Future<void> _processAssetBatch(
    List<AssetEntity> assets,
    List<PhotoSyncRecord> newRecords,
  ) async {
    for (final asset in assets) {
      try {
        // 检查资源是否存在
        if (!await asset.exists) {
          print('跳过已删除的资源: ${asset.id}');
          continue;
        }

        // 获取文件（添加超时和错误处理）
        File? file;
        try {
          file = await asset.file?.timeout(
            const Duration(seconds: 10),
            onTimeout: () => null,
          );
        } catch (e) {
          print('获取文件超时或失败: ${asset.id}, 错误: $e');
          continue;
        }

        if (file == null) {
          print('无法获取文件: ${asset.id}');
          continue;
        }

        if (!await file.exists()) {
          print('文件不存在: ${file.path}');
          continue;
        }

        // 检查文件大小（跳过过大的文件以防止内存问题）
        final fileStats = await file.stat();
        const maxFileSize = 100 * 1024 * 1024; // 100MB 限制
        if (fileStats.size > maxFileSize) {
          print('文件过大，跳过: ${file.path} (${fileStats.size} bytes)');
          continue;
        }

        // 计算文件哈希（添加错误处理）
        String fileHash;
        try {
          fileHash = await _calculateFileHash(file);
        } catch (e) {
          print('计算文件哈希失败: ${file.path}, 错误: $e');
          continue;
        }

        // 检查是否已存在
        final existingRecord = await SyncDatabaseService.getByHash(fileHash);
        if (existingRecord != null) {
          print('文件已存在记录，跳过: ${file.path}');
          continue;
        }

        // 创建新的同步记录
        final record = PhotoSyncRecord(
          id: asset.id,
          localPath: file.path,
          fileName: path.basename(file.path),
          fileHash: fileHash,
          fileSize: fileStats.size,
          createdTime: asset.createDateTime,
          modifiedTime: asset.modifiedDateTime,
          remotePath: await _generateRemotePath(file.path),
          status: SyncStatus.pending,
        );

        newRecords.add(record);
        print('添加新记录: ${record.fileName}');
      } catch (e) {
        print('处理资源失败: ${asset.id}, 错误: $e');
        // 继续处理下一个资源，不中断整个流程
      }
    }
  }

  /// 开始同步
  Future<void> startSync(WebDavService webDavService) async {
    if (_isSyncing) return;

    _isSyncing = true;
    _errorMessage = null;
    _processedFiles = 0;
    _uploadedFiles = 0;
    _skippedFiles = 0;
    _failedFiles = 0;
    notifyListeners();

    try {
      // 确保相册文件夹存在
      await _ensureAlbumFolderExists(webDavService);

      // 获取待同步的记录
      final pendingRecords = await SyncDatabaseService.getPendingRecords();
      _totalFiles = pendingRecords.length;

      if (_totalFiles == 0) {
        _isSyncing = false;
        notifyListeners();
        return;
      }

      // 分批处理
      for (int i = 0; i < pendingRecords.length; i += BATCH_SIZE) {
        if (!_isSyncing) break; // 检查是否已停止

        final batch = pendingRecords.skip(i).take(BATCH_SIZE).toList();
        await _processBatch(webDavService, batch);
      }
    } catch (e) {
      _errorMessage = '同步失败: $e';
    } finally {
      _isSyncing = false;
      _currentUploading = null;
      notifyListeners();
    }
  }

  /// 停止同步
  void stopSync() {
    _isSyncing = false;
    _currentUploading = null;
    notifyListeners();
  }

  /// 处理批次
  Future<void> _processBatch(
    WebDavService webDavService,
    List<PhotoSyncRecord> batch,
  ) async {
    for (final record in batch) {
      if (!_isSyncing) break;

      _currentUploading = record;
      notifyListeners();

      await _uploadSingleFile(webDavService, record);

      _processedFiles++;
      notifyListeners();
    }
  }

  /// 上传单个文件
  Future<void> _uploadSingleFile(
    WebDavService webDavService,
    PhotoSyncRecord record,
  ) async {
    try {
      // 更新状态为上传中
      await SyncDatabaseService.updateStatus(record.id, SyncStatus.uploading);

      // 检查本地文件是否存在
      final localFile = File(record.localPath);
      if (!await localFile.exists()) {
        await SyncDatabaseService.updateStatus(
          record.id,
          SyncStatus.failed,
          errorMessage: '本地文件不存在',
        );
        _failedFiles++;
        return;
      }

      // 检查远程文件是否已存在
      final remoteExists = await webDavService.fileExists(record.remotePath);
      if (remoteExists) {
        await SyncDatabaseService.updateStatus(record.id, SyncStatus.skipped);
        _skippedFiles++;
        return;
      }

      // 读取文件数据
      final fileData = await localFile.readAsBytes();

      // 上传文件
      final success = await webDavService.uploadFile(
        record.remotePath,
        fileData,
      );

      if (success) {
        await SyncDatabaseService.updateStatus(
          record.id,
          SyncStatus.completed,
          lastSyncTime: DateTime.now(),
        );
        _uploadedFiles++;
      } else {
        // 增加重试次数
        final newRetryCount = record.retryCount + 1;
        final status = newRetryCount >= MAX_RETRY_COUNT
            ? SyncStatus.failed
            : SyncStatus.pending;

        await SyncDatabaseService.updateStatus(
          record.id,
          status,
          errorMessage: '上传失败',
          retryCount: newRetryCount,
        );

        if (status == SyncStatus.failed) {
          _failedFiles++;
        }
      }
    } catch (e) {
      // 处理异常
      final newRetryCount = record.retryCount + 1;
      final status = newRetryCount >= MAX_RETRY_COUNT
          ? SyncStatus.failed
          : SyncStatus.pending;

      await SyncDatabaseService.updateStatus(
        record.id,
        status,
        errorMessage: e.toString(),
        retryCount: newRetryCount,
      );

      if (status == SyncStatus.failed) {
        _failedFiles++;
      }
    }
  }

  /// 确保相册文件夹存在
  Future<void> _ensureAlbumFolderExists(WebDavService webDavService) async {
    final albumPath = '/$ALBUM_FOLDER_NAME/';
    final exists = await webDavService.fileExists(albumPath);

    if (!exists) {
      await webDavService.createDirectory(albumPath);
    }
  }

  /// 生成远程路径
  Future<String> _generateRemotePath(String localPath) async {
    final fileName = path.basename(localPath);
    final extension = path.extension(fileName).toLowerCase();

    // 根据文件类型分类存储
    String subFolder = '';
    if ([
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.bmp',
      '.webp',
    ].contains(extension)) {
      subFolder = '图片/';
    } else if ([
      '.mp4',
      '.mov',
      '.avi',
      '.mkv',
      '.3gp',
      '.webm',
    ].contains(extension)) {
      subFolder = '视频/';
    } else {
      subFolder = '其他/';
    }

    return '/$ALBUM_FOLDER_NAME/$subFolder$fileName';
  }

  /// 计算文件哈希值
  Future<String> _calculateFileHash(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final digest = sha256.convert(bytes);
      return digest.toString();
    } catch (e) {
      // 如果无法计算哈希，使用文件路径和大小的组合
      final stat = await file.stat();
      return sha256
          .convert(
            utf8.encode(
              '${file.path}_${stat.size}_${stat.modified.millisecondsSinceEpoch}',
            ),
          )
          .toString();
    }
  }

  /// 获取同步统计信息
  Future<SyncStatistics> getStatistics() async {
    return await SyncDatabaseService.getStatistics();
  }

  /// 重置同步记录
  Future<void> resetSyncRecords() async {
    await SyncDatabaseService.clearAll();
    _totalFiles = 0;
    _processedFiles = 0;
    _uploadedFiles = 0;
    _skippedFiles = 0;
    _failedFiles = 0;
    notifyListeners();
  }

  /// 清理失败记录
  Future<void> cleanupFailedRecords() async {
    await SyncDatabaseService.cleanupFailedRecords();
    notifyListeners();
  }

  /// 重试失败的上传
  Future<void> retryFailedUploads(WebDavService webDavService) async {
    final failedRecords = await SyncDatabaseService.getByStatus(
      SyncStatus.failed,
    );

    // 重置失败记录为待上传状态
    for (final record in failedRecords) {
      await SyncDatabaseService.updateStatus(
        record.id,
        SyncStatus.pending,
        retryCount: 0,
        errorMessage: null,
      );
    }

    // 开始同步
    await startSync(webDavService);
  }

  @override
  void dispose() {
    _isSyncing = false;
    super.dispose();
  }
}
