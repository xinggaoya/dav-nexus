import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:isolate';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as path;

import '../models/photo_sync_record.dart';
import '../services/sync_database_service.dart';
import '../services/webdav_service.dart';
import '../services/notification_service.dart';
import '../providers/app_settings_provider.dart';

/// 相册同步服务
class PhotoSyncService extends ChangeNotifier {
  static const String ALBUM_FOLDER_NAME = '相册';
  static const int BATCH_SIZE = 3; // 减少批量处理大小
  static const int MAX_RETRY_COUNT = 3; // 最大重试次数
  static const int PROCESS_BATCH_SIZE = 1; // 流式处理批次大小
  static const int MAX_FILES_PER_SESSION = 2000; // 增加处理限制

  bool _isProcessing = false; // 改为处理状态，不再区分扫描和同步
  bool _isInitialized = false;
  String? _errorMessage;
  bool _shouldCancel = false;
  bool _isPaused = false; // 添加暂停状态

  int _totalFiles = 0;
  int _processedFiles = 0;
  int _uploadedFiles = 0;
  int _skippedFiles = 0;
  int _failedFiles = 0;

  PhotoSyncRecord? _currentUploading;
  AppSettingsProvider? _appSettings;

  // 添加已处理资源的记录，用于识别动态照片关联的资源
  final Set<String> _processedAssetIds = {};
  // 记录动态照片的关联ID
  final Map<String, List<String>> _livePhotoGroups = {};

  // Getters
  bool get isScanning => false; // 不再有扫描阶段
  bool get isSyncing => _isProcessing; // 兼容原有接口
  bool get isProcessing => _isProcessing;
  bool get isPaused => _isPaused;
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

  String get progressPercent {
    return '${(progress * 100).toStringAsFixed(1)}%';
  }

  /// 设置应用设置提供者
  void setAppSettings(AppSettingsProvider appSettings) {
    _appSettings = appSettings;
  }

  /// 检查是否应该自动同步
  bool get shouldAutoSync {
    return _appSettings?.autoSync ?? false;
  }

  /// 检查是否仅WiFi同步
  bool get shouldSyncWifiOnly {
    return _appSettings?.autoSyncWifiOnly ?? false;
  }

  /// 检查是否自动备份
  bool get shouldAutoBackup {
    return _appSettings?.autoBackup ?? false;
  }

  /// 取消当前操作
  void cancelCurrentOperation() {
    _shouldCancel = true;
    _isProcessing = false;
    _isPaused = false;

    // 发送取消通知
    NotificationService.showSyncCancelled();
    NotificationService.clearSyncNotification();

    notifyListeners();
  }

  /// 暂停处理
  void pauseProcessing() {
    if (_isProcessing && !_isPaused) {
      _isPaused = true;

      // 发送暂停通知
      NotificationService.showSyncPaused(
        current: _processedFiles,
        total: _totalFiles,
      );

      notifyListeners();
    }
  }

  /// 恢复处理
  void resumeProcessing() {
    if (_isProcessing && _isPaused) {
      _isPaused = false;

      // 清除暂停通知，继续显示进度通知
      NotificationService.updateSyncProgress(
        current: _processedFiles,
        total: _totalFiles,
        uploaded: _uploadedFiles,
        failed: _failedFiles,
        skipped: _skippedFiles,
        currentFileName: _currentUploading?.fileName,
      );

      notifyListeners();
    }
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

      // 初始化通知服务
      await NotificationService.initialize();

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

  /// 快速获取文件总数
  Future<int> _getFilesTotalCount() async {
    print('正在快速计算文件总数...');

    // 获取所有相册
    final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      onlyAll: false,
    );

    // 使用Set收集所有不重复的资源ID
    final Set<String> uniqueAssetIds = {};

    // 收集具有相同文件名的资源
    final Map<String, List<AssetEntity>> assetsByName = {};

    for (final album in albums) {
      const pageSize = 100;
      int page = 0;

      while (true) {
        final assets = await album.getAssetListPaged(
          page: page,
          size: pageSize,
        );

        if (assets.isEmpty) break;

        for (final asset in assets) {
          uniqueAssetIds.add(asset.id);

          // 按文件名分组
          final fileName = asset.title ?? '';
          if (fileName.isNotEmpty) {
            final baseName = path.basenameWithoutExtension(fileName);
            if (!assetsByName.containsKey(baseName)) {
              assetsByName[baseName] = [];
            }
            assetsByName[baseName]!.add(asset);
          }
        }

        page++;
        if (assets.length < pageSize) break;
      }

      // 短暂暂停，让UI响应
      await Future.delayed(const Duration(milliseconds: 10));
    }

    // 分析找到具有相同文件名但不同类型的资源（可能是动态照片）
    int duplicatesCount = 0;
    for (final entry in assetsByName.entries) {
      final assets = entry.value;
      if (assets.length > 1) {
        // 检查是否包含图片和视频组合
        bool hasImage = assets.any((a) => a.type == AssetType.image);
        bool hasVideo = assets.any((a) => a.type == AssetType.video);

        if (hasImage && hasVideo) {
          // 减去重复数量 (减去视频数量，只保留图片)
          duplicatesCount += assets
              .where((a) => a.type == AssetType.video)
              .length;
        }
      }
    }

    print('总计发现 ${uniqueAssetIds.length} 个资源，其中疑似动态照片相关联资源 $duplicatesCount 个');

    // 从总数中减去可能的关联资源数量
    final adjustedCount = uniqueAssetIds.length - duplicatesCount;
    return adjustedCount;
  }

  /// 预处理扫描，识别Live Photos和动态照片组
  Future<void> _identifyLivePhotoGroups(List<AssetPathEntity> albums) async {
    print('开始识别动态照片组...');

    // 按文件名基础部分收集所有资源
    final Map<String, List<AssetEntity>> assetsByBaseName = {};

    for (final album in albums) {
      if (_shouldCancel) break;

      final assetCount = await album.assetCountAsync;
      if (assetCount == 0) continue;

      const pageSize = 100; // 增大批量，加快处理
      int page = 0;

      while (!_shouldCancel) {
        final List<AssetEntity> assets = await album.getAssetListPaged(
          page: page,
          size: pageSize,
        );

        if (assets.isEmpty) break;

        // 收集所有资源信息，按文件名基础部分分组
        for (final asset in assets) {
          final fileName = asset.title ?? '';
          if (fileName.isEmpty) continue;

          final baseName = path.basenameWithoutExtension(fileName);
          if (baseName.isEmpty) continue;

          if (!assetsByBaseName.containsKey(baseName)) {
            assetsByBaseName[baseName] = [];
          }
          assetsByBaseName[baseName]!.add(asset);
        }

        page++;
        if (assets.length < pageSize) break; // 处理完毕

        // 短暂暂停让UI响应
        await Future.delayed(const Duration(milliseconds: 20));
      }
    }

    // 分析所有同名资源组，找出动态照片
    int identifiedGroups = 0;
    for (final entry in assetsByBaseName.entries) {
      final baseName = entry.key;
      final assets = entry.value;

      // 忽略单个资源
      if (assets.length <= 1) continue;

      // 检查是否包含图片和视频组合
      final imageAssets = assets
          .where((a) => a.type == AssetType.image)
          .toList();
      final videoAssets = assets
          .where((a) => a.type == AssetType.video)
          .toList();

      if (imageAssets.isEmpty || videoAssets.isEmpty) continue;

      // 找到了可能的动态照片组合
      // 进一步检查创建时间是否接近（5秒内）
      for (final image in imageAssets) {
        final imageTime = image.createDateTime.millisecondsSinceEpoch;

        for (final video in videoAssets) {
          final videoTime = video.createDateTime.millisecondsSinceEpoch;
          final timeDiff = (imageTime - videoTime).abs();

          // 如果创建时间相差在5秒内，认为是同一个动态照片
          if (timeDiff < 5000) {
            print(
              '找到动态照片组: ${image.title} (${image.id}) + ${video.title} (${video.id})',
            );

            // 将图片作为主资源，视频作为关联资源
            if (!_livePhotoGroups.containsKey(image.id)) {
              _livePhotoGroups[image.id] = [];
            }
            _livePhotoGroups[image.id]!.add(video.id);
            identifiedGroups++;
          }
        }
      }
    }

    print(
      '动态照片组识别完成，找到 $identifiedGroups 组，涉及 ${_livePhotoGroups.length} 个主资源',
    );

    // 打印总计需要忽略的资源数量
    int ignoredCount = 0;
    for (final relatedIds in _livePhotoGroups.values) {
      ignoredCount += relatedIds.length;
    }

    print('将忽略 $ignoredCount 个关联资源（主要是视频部分）');

    // 更新实际处理的文件数量
    if (_totalFiles > ignoredCount) {
      _totalFiles -= ignoredCount;
      notifyListeners();
    }
  }

  /// 流式处理和同步（替代原来的扫描+同步两个步骤）
  Future<void> startProcessingAndSync(WebDavService webDavService) async {
    if (_isProcessing) return;

    _isProcessing = true;
    _errorMessage = null;
    _processedFiles = 0;
    _uploadedFiles = 0;
    _skippedFiles = 0;
    _failedFiles = 0;
    _shouldCancel = false;
    _currentUploading = null;
    // 清空已处理资源记录
    _processedAssetIds.clear();
    _livePhotoGroups.clear();
    notifyListeners();

    try {
      print('开始流式处理和同步...');

      // 发送开始通知
      await NotificationService.showSyncStarted();

      // 检查权限
      final hasPermission = await _requestPhotoPermission();
      if (!hasPermission) {
        _errorMessage = '没有相册访问权限，请在设置中允许访问相册';
        return;
      }

      // 确保相册文件夹存在
      await _ensureAlbumFolderExists(webDavService);

      // 获取相册列表
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.common,
        onlyAll: false,
      );

      if (albums.isEmpty) {
        _errorMessage = '未找到任何相册';
        return;
      }

      // 优先处理相机相册
      albums.sort((a, b) => a.name == 'Camera' || a.name == '相机' ? -1 : 1);

      // 预处理扫描，识别Live Photos和动态照片组
      print('预处理扫描，识别动态照片组...');
      await _identifyLivePhotoGroups(albums);

      // 快速获取实际处理的总文件数（已经减去动态照片关联项）
      final totalCount = await _getFilesTotalCount();
      final maxProcessFiles = totalCount > MAX_FILES_PER_SESSION
          ? MAX_FILES_PER_SESSION
          : totalCount;

      _totalFiles = maxProcessFiles;
      print('总计 $totalCount 个文件，本次处理 $maxProcessFiles 个');

      if (totalCount > MAX_FILES_PER_SESSION) {
        _errorMessage =
            '检测到 $totalCount 个文件，本次将处理前 $maxProcessFiles 个文件，建议分批次同步';
        notifyListeners();
      }

      // 流式处理每个相册
      for (final album in albums) {
        if (_shouldCancel || _processedFiles >= maxProcessFiles) {
          print('处理被取消或达到限制');
          break;
        }

        await _processAlbumStreaming(album, webDavService, maxProcessFiles);

        // 检查是否暂停
        while (_isPaused && !_shouldCancel) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }

      print(
        '处理完成！总计: $_totalFiles, 已处理: $_processedFiles, 上传: $_uploadedFiles, 跳过: $_skippedFiles, 失败: $_failedFiles',
      );

      // 发送完成通知
      await NotificationService.showSyncCompleted(
        total: _totalFiles,
        uploaded: _uploadedFiles,
        failed: _failedFiles,
        skipped: _skippedFiles,
      );
    } catch (e) {
      print('处理失败: $e');
      _errorMessage = '处理失败: $e';

      // 发送失败通知
      await NotificationService.showSyncCompleted(
        total: _totalFiles,
        uploaded: _uploadedFiles,
        failed: _failedFiles + 1, // 添加此次失败
        skipped: _skippedFiles,
      );
    } finally {
      _isProcessing = false;
      _currentUploading = null;

      // 清除进度通知
      await NotificationService.clearSyncNotification();

      notifyListeners();
    }
  }

  /// 流式处理单个相册
  Future<void> _processAlbumStreaming(
    AssetPathEntity album,
    WebDavService webDavService,
    int maxProcessFiles,
  ) async {
    print('流式处理相册: ${album.name}');

    final assetCount = await album.assetCountAsync;
    if (assetCount == 0) return;

    const pageSize = 10; // 更小的页面大小
    int page = 0;

    while (_processedFiles < maxProcessFiles && !_shouldCancel) {
      final List<AssetEntity> assets = await album.getAssetListPaged(
        page: page,
        size: pageSize,
      );

      if (assets.isEmpty) break;

      // 逐个处理文件
      for (final asset in assets) {
        if (_shouldCancel || _processedFiles >= maxProcessFiles) break;

        // 检查是否暂停
        while (_isPaused && !_shouldCancel) {
          await Future.delayed(const Duration(milliseconds: 100));
        }

        if (_shouldCancel) break;

        // 检查是否已处理过该资源（避免重复处理动态照片的关联资源）
        if (_processedAssetIds.contains(asset.id)) {
          print('跳过已处理的资源: ${asset.id}');
          continue;
        }

        // 检查该资源是否是某个动态照片的关联资源
        bool isSecondaryAsset = false;
        for (final entry in _livePhotoGroups.entries) {
          if (entry.value.contains(asset.id)) {
            isSecondaryAsset = true;
            print('跳过动态照片的关联资源: ${asset.id}，主资源为 ${entry.key}');
            _processedAssetIds.add(asset.id); // 标记为已处理
            break;
          }
        }

        if (isSecondaryAsset) {
          // 跳过动态照片的关联资源（只处理主图像）
          continue;
        }

        await _processAndUploadSingleFile(asset, webDavService);

        // 标记该资源为已处理
        _processedAssetIds.add(asset.id);

        // 如果这是一个动态照片，标记其关联资源为已处理
        if (_livePhotoGroups.containsKey(asset.id)) {
          for (final relatedId in _livePhotoGroups[asset.id]!) {
            _processedAssetIds.add(relatedId);
            print('标记动态照片关联资源为已处理: $relatedId');
          }
        }

        _processedFiles++;

        // 更新进度通知（如果不是暂停状态）
        if (!_isPaused) {
          await NotificationService.updateSyncProgress(
            current: _processedFiles,
            total: _totalFiles,
            uploaded: _uploadedFiles,
            failed: _failedFiles,
            skipped: _skippedFiles,
            currentFileName: _currentUploading?.fileName,
          );
        }

        notifyListeners();

        // 短暂暂停让UI响应
        await Future.delayed(const Duration(milliseconds: 50));
      }

      page++;
      if (page > 100) break; // 防止无限循环
    }
  }

  /// 处理并上传单个文件
  Future<void> _processAndUploadSingleFile(
    AssetEntity asset,
    WebDavService webDavService,
  ) async {
    try {
      // 检查资源是否存在
      if (!await asset.exists) {
        print('跳过已删除的资源: ${asset.id}');
        _skippedFiles++;
        return;
      }

      // 获取文件
      File? file;
      try {
        file = await asset.file?.timeout(
          const Duration(seconds: 5),
          onTimeout: () => null,
        );
      } catch (e) {
        print('获取文件失败: ${asset.id}, 错误: $e');
        _failedFiles++;

        // 创建失败记录
        final record = PhotoSyncRecord(
          id: asset.id,
          localPath: '',
          fileName: 'unknown_${asset.id}',
          fileHash: '',
          fileSize: 0,
          createdTime: asset.createDateTime,
          modifiedTime: asset.modifiedDateTime,
          remotePath: '',
          status: SyncStatus.failed,
          errorMessage: '获取文件失败: $e',
        );
        await SyncDatabaseService.insertOrUpdate(record);
        return;
      }

      if (file == null || !await file.exists()) {
        print('文件不存在: ${asset.id}');
        _skippedFiles++;
        return;
      }

      // 检查文件大小
      final fileStats = await file.stat();
      const maxFileSize = 50 * 1024 * 1024; // 50MB
      if (fileStats.size > maxFileSize) {
        print('文件过大，跳过: ${file.path}');
        _skippedFiles++;
        return;
      }

      // 快速计算哈希
      String fileHash;
      try {
        fileHash = await _calculateFileHashFast(file);
      } catch (e) {
        print('计算哈希失败: ${file.path}');
        _skippedFiles++;
        return;
      }

      // 检查是否已存在记录
      final existingRecord = await SyncDatabaseService.getByHash(fileHash);
      if (existingRecord != null) {
        if (existingRecord.status == SyncStatus.completed) {
          print('文件已同步，跳过: ${file.path}');
          _skippedFiles++;
          return;
        }
      }

      // 创建同步记录
      final record = PhotoSyncRecord(
        id: asset.id,
        localPath: file.path,
        fileName: path.basename(file.path),
        fileHash: fileHash,
        fileSize: fileStats.size,
        createdTime: asset.createDateTime,
        modifiedTime: asset.modifiedDateTime,
        remotePath: await _generateRemotePath(file.path),
        status: SyncStatus.uploading,
      );

      _currentUploading = record;
      notifyListeners();

      // 保存记录
      await SyncDatabaseService.insertOrUpdate(record);

      // 直接上传
      final success = await _uploadFile(webDavService, record);

      if (success) {
        _uploadedFiles++;
        await SyncDatabaseService.updateStatus(
          record.id,
          SyncStatus.completed,
          lastSyncTime: DateTime.now(),
        );
        print('上传成功: ${record.fileName}');
      } else {
        _failedFiles++;
        await SyncDatabaseService.updateStatus(
          record.id,
          SyncStatus.failed,
          errorMessage: '上传失败',
          lastSyncTime: DateTime.now(),
        );
        print('上传失败: ${record.fileName}');
      }
    } catch (e) {
      print('处理文件失败: ${asset.id}, 错误: $e');
      _failedFiles++;
    }
  }

  /// 上传单个文件
  Future<bool> _uploadFile(
    WebDavService webDavService,
    PhotoSyncRecord record,
  ) async {
    try {
      final file = File(record.localPath);
      if (!await file.exists()) {
        print('文件不存在: ${record.localPath}');
        return false;
      }

      final bytes = await file.readAsBytes();
      final success = await webDavService.uploadFile(record.remotePath, bytes);

      return success;
    } catch (e) {
      print('上传文件失败: ${record.fileName}, 错误: $e');
      return false;
    }
  }

  /// 快速计算文件哈希（只计算文件开头部分）
  Future<String> _calculateFileHashFast(File file) async {
    try {
      final fileSize = await file.length();
      const maxSampleSize = 512 * 1024; // 减少到512KB，更快

      final bytesToRead = fileSize > maxSampleSize ? maxSampleSize : fileSize;
      final bytes = await file.openRead(0, bytesToRead).first;

      // 结合文件大小和部分内容创建更快的哈希
      final hash = sha256.convert([...bytes, ...fileSize.toString().codeUnits]);
      return hash.toString();
    } catch (e) {
      // 如果快速方法失败，回退到简单哈希
      final stats = await file.stat();
      return '${stats.size}_${stats.modified.millisecondsSinceEpoch}';
    }
  }

  /// 生成远程路径
  Future<String> _generateRemotePath(String localPath) async {
    final fileName = path.basename(localPath);

    // 根据文件类型分子文件夹
    final extension = path.extension(fileName).toLowerCase();
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
      '.avi',
      '.mov',
      '.mkv',
      '.webm',
      '.3gp',
    ].contains(extension)) {
      subFolder = '视频/';
    } else {
      subFolder = '其他/';
    }

    return '/$ALBUM_FOLDER_NAME/$subFolder$fileName';
  }

  /// 确保相册文件夹存在
  Future<void> _ensureAlbumFolderExists(WebDavService webDavService) async {
    try {
      // 创建主文件夹
      await webDavService.createDirectory('/$ALBUM_FOLDER_NAME');

      // 创建子文件夹
      await webDavService.createDirectory('/$ALBUM_FOLDER_NAME/图片');
      await webDavService.createDirectory('/$ALBUM_FOLDER_NAME/视频');
      await webDavService.createDirectory('/$ALBUM_FOLDER_NAME/其他');
    } catch (e) {
      print('创建相册文件夹失败: $e');
      // 不抛出异常，因为文件夹可能已存在
    }
  }

  // 兼容性方法：保留原有接口
  Future<void> scanLocalPhotos() async {
    print('scanLocalPhotos 已废弃，请使用 startProcessingAndSync');
  }

  Future<void> startSync(WebDavService webDavService) async {
    await startProcessingAndSync(webDavService);
  }

  /// 获取同步统计信息
  Future<SyncStatistics> getStatistics() async {
    return await SyncDatabaseService.getStatistics();
  }

  /// 获取本地相册总统计信息
  Future<LocalPhotoStatistics> getLocalPhotoStatistics() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // 获取所有相册
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.common,
        onlyAll: false,
      );

      int totalPhotos = 0;
      int totalVideos = 0;
      int totalSize = 0;

      // 使用Set收集唯一资源ID，避免重复计算
      final Set<String> processedPhotoIds = {};
      final Set<String> processedVideoIds = {};

      // 按文件名收集资源，用于检测动态照片
      final Map<String, List<AssetEntity>> assetsByName = {};

      // 使用更快的统计方法，只计算数量不读取具体文件
      for (final album in albums) {
        // 分批获取资源以避免内存问题
        const batchSize = 100;
        int page = 0;

        while (true) {
          final assets = await album.getAssetListPaged(
            page: page,
            size: batchSize,
          );

          if (assets.isEmpty) break;

          for (final asset in assets) {
            // 按文件名分组
            final fileName = asset.title ?? '';
            if (fileName.isNotEmpty) {
              final baseName = path.basenameWithoutExtension(fileName);
              if (!assetsByName.containsKey(baseName)) {
                assetsByName[baseName] = [];
              }
              assetsByName[baseName]!.add(asset);
            }

            if (asset.type == AssetType.image &&
                !processedPhotoIds.contains(asset.id)) {
              totalPhotos++;
              totalSize += 2 * 1024 * 1024; // 估算图片2MB
              processedPhotoIds.add(asset.id);
            } else if (asset.type == AssetType.video &&
                !processedVideoIds.contains(asset.id)) {
              // 检查是否为动态照片的一部分
              bool isPartOfLivePhoto = false;
              final baseName = path.basenameWithoutExtension(asset.title ?? '');

              if (assetsByName.containsKey(baseName)) {
                final group = assetsByName[baseName]!;
                if (group.length > 1 &&
                    group.any((a) => a.type == AssetType.image)) {
                  isPartOfLivePhoto = true;
                }
              }

              // 如果不是动态照片的一部分，才计算为独立视频
              if (!isPartOfLivePhoto) {
                totalVideos++;
                totalSize += 20 * 1024 * 1024; // 估算视频20MB
              }
              processedVideoIds.add(asset.id);
            }
          }

          page++;
          if (assets.length < batchSize) break;

          // 每批次后短暂暂停，让UI响应
          await Future.delayed(const Duration(milliseconds: 10));
        }
      }

      print(
        '统计结果：照片 $totalPhotos 张，视频 $totalVideos 个，总计 ${totalPhotos + totalVideos} 个文件',
      );

      return LocalPhotoStatistics(
        totalPhotos: totalPhotos,
        totalVideos: totalVideos,
        totalFiles: totalPhotos + totalVideos,
        estimatedSize: totalSize,
      );
    } catch (e) {
      print('获取本地相册统计失败: $e');

      // 降级方案：使用改进的总数统计
      try {
        final totalCount = await _getFilesTotalCount();
        // 估算图片视频比例 (80% 图片，20% 视频)
        final estimatedPhotos = (totalCount * 0.8).round();
        final estimatedVideos = totalCount - estimatedPhotos;

        return LocalPhotoStatistics(
          totalPhotos: estimatedPhotos,
          totalVideos: estimatedVideos,
          totalFiles: totalCount,
          estimatedSize:
              estimatedPhotos * 2 * 1024 * 1024 +
              estimatedVideos * 20 * 1024 * 1024,
        );
      } catch (fallbackError) {
        print('降级统计也失败: $fallbackError');
        return LocalPhotoStatistics(
          totalPhotos: 0,
          totalVideos: 0,
          totalFiles: 0,
          estimatedSize: 0,
        );
      }
    }
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
    _isProcessing = false;
    super.dispose();
  }
}

/// 本地相册统计信息
class LocalPhotoStatistics {
  final int totalPhotos; // 总图片数
  final int totalVideos; // 总视频数
  final int totalFiles; // 总文件数
  final int estimatedSize; // 估算总大小

  LocalPhotoStatistics({
    required this.totalPhotos,
    required this.totalVideos,
    required this.totalFiles,
    required this.estimatedSize,
  });
}
