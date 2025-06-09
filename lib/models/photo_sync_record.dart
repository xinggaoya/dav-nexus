/// 相册同步记录模型
class PhotoSyncRecord {
  final String id; // 本地资源ID
  final String localPath; // 本地文件路径
  final String fileName; // 文件名
  final String fileHash; // 文件哈希值（用于去重）
  final int fileSize; // 文件大小
  final DateTime createdTime; // 创建时间
  final DateTime modifiedTime; // 修改时间
  final String remotePath; // 云端路径
  final SyncStatus status; // 同步状态
  final int retryCount; // 重试次数
  final DateTime? lastSyncTime; // 最后同步时间
  final String? errorMessage; // 错误信息

  PhotoSyncRecord({
    required this.id,
    required this.localPath,
    required this.fileName,
    required this.fileHash,
    required this.fileSize,
    required this.createdTime,
    required this.modifiedTime,
    required this.remotePath,
    required this.status,
    this.retryCount = 0,
    this.lastSyncTime,
    this.errorMessage,
  });

  /// 从Map创建对象
  factory PhotoSyncRecord.fromMap(Map<String, dynamic> map) {
    return PhotoSyncRecord(
      id: map['id'],
      localPath: map['local_path'],
      fileName: map['file_name'],
      fileHash: map['file_hash'],
      fileSize: map['file_size'],
      createdTime: DateTime.fromMillisecondsSinceEpoch(map['created_time']),
      modifiedTime: DateTime.fromMillisecondsSinceEpoch(map['modified_time']),
      remotePath: map['remote_path'],
      status: SyncStatus.values[map['status']],
      retryCount: map['retry_count'] ?? 0,
      lastSyncTime: map['last_sync_time'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['last_sync_time'])
          : null,
      errorMessage: map['error_message'],
    );
  }

  /// 转换为Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'local_path': localPath,
      'file_name': fileName,
      'file_hash': fileHash,
      'file_size': fileSize,
      'created_time': createdTime.millisecondsSinceEpoch,
      'modified_time': modifiedTime.millisecondsSinceEpoch,
      'remote_path': remotePath,
      'status': status.index,
      'retry_count': retryCount,
      'last_sync_time': lastSyncTime?.millisecondsSinceEpoch,
      'error_message': errorMessage,
    };
  }

  /// 复制并更新部分字段
  PhotoSyncRecord copyWith({
    String? id,
    String? localPath,
    String? fileName,
    String? fileHash,
    int? fileSize,
    DateTime? createdTime,
    DateTime? modifiedTime,
    String? remotePath,
    SyncStatus? status,
    int? retryCount,
    DateTime? lastSyncTime,
    String? errorMessage,
  }) {
    return PhotoSyncRecord(
      id: id ?? this.id,
      localPath: localPath ?? this.localPath,
      fileName: fileName ?? this.fileName,
      fileHash: fileHash ?? this.fileHash,
      fileSize: fileSize ?? this.fileSize,
      createdTime: createdTime ?? this.createdTime,
      modifiedTime: modifiedTime ?? this.modifiedTime,
      remotePath: remotePath ?? this.remotePath,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  String toString() {
    return 'PhotoSyncRecord{id: $id, fileName: $fileName, status: $status}';
  }
}

/// 同步状态枚举
enum SyncStatus {
  pending, // 待同步
  uploading, // 上传中
  completed, // 已完成
  failed, // 失败
  skipped, // 跳过（已存在）
}

/// 同步状态扩展
extension SyncStatusExtension on SyncStatus {
  String get displayName {
    switch (this) {
      case SyncStatus.pending:
        return '待同步';
      case SyncStatus.uploading:
        return '上传中';
      case SyncStatus.completed:
        return '已完成';
      case SyncStatus.failed:
        return '失败';
      case SyncStatus.skipped:
        return '跳过';
    }
  }

  bool get isFinished {
    return this == SyncStatus.completed || this == SyncStatus.skipped;
  }

  bool get needsRetry {
    return this == SyncStatus.failed || this == SyncStatus.pending;
  }
}
