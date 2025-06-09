import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/photo_sync_record.dart';

/// 同步数据库服务
class SyncDatabaseService {
  static const String _databaseName = 'photo_sync.db';
  static const int _databaseVersion = 1;
  static const String _tableName = 'sync_records';

  static Database? _database;

  /// 获取数据库实例
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// 初始化数据库
  static Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// 创建数据表
  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id TEXT PRIMARY KEY,
        local_path TEXT NOT NULL,
        file_name TEXT NOT NULL,
        file_hash TEXT NOT NULL,
        file_size INTEGER NOT NULL,
        created_time INTEGER NOT NULL,
        modified_time INTEGER NOT NULL,
        remote_path TEXT NOT NULL,
        status INTEGER NOT NULL,
        retry_count INTEGER DEFAULT 0,
        last_sync_time INTEGER,
        error_message TEXT,
        UNIQUE(file_hash)
      )
    ''');

    // 创建索引以提高查询性能
    await db.execute('''
      CREATE INDEX idx_file_hash ON $_tableName (file_hash)
    ''');

    await db.execute('''
      CREATE INDEX idx_status ON $_tableName (status)
    ''');

    await db.execute('''
      CREATE INDEX idx_created_time ON $_tableName (created_time)
    ''');
  }

  /// 数据库升级
  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // 如果需要升级数据库结构，在这里处理
  }

  /// 插入或更新同步记录
  static Future<int> insertOrUpdate(PhotoSyncRecord record) async {
    final db = await database;

    return await db.insert(
      _tableName,
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 批量插入记录
  static Future<void> insertBatch(List<PhotoSyncRecord> records) async {
    final db = await database;
    final batch = db.batch();

    for (final record in records) {
      batch.insert(
        _tableName,
        record.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// 根据ID获取记录
  static Future<PhotoSyncRecord?> getById(String id) async {
    final db = await database;
    final maps = await db.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return PhotoSyncRecord.fromMap(maps.first);
    }
    return null;
  }

  /// 根据文件哈希获取记录
  static Future<PhotoSyncRecord?> getByHash(String fileHash) async {
    final db = await database;
    final maps = await db.query(
      _tableName,
      where: 'file_hash = ?',
      whereArgs: [fileHash],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return PhotoSyncRecord.fromMap(maps.first);
    }
    return null;
  }

  /// 获取指定状态的记录
  static Future<List<PhotoSyncRecord>> getByStatus(SyncStatus status) async {
    final db = await database;
    final maps = await db.query(
      _tableName,
      where: 'status = ?',
      whereArgs: [status.index],
      orderBy: 'created_time ASC',
    );

    return maps.map((map) => PhotoSyncRecord.fromMap(map)).toList();
  }

  /// 获取待同步的记录（包括失败和待上传）
  static Future<List<PhotoSyncRecord>> getPendingRecords() async {
    final db = await database;
    final maps = await db.query(
      _tableName,
      where: 'status IN (?, ?)',
      whereArgs: [SyncStatus.pending.index, SyncStatus.failed.index],
      orderBy: 'created_time ASC',
    );

    return maps.map((map) => PhotoSyncRecord.fromMap(map)).toList();
  }

  /// 获取所有记录
  static Future<List<PhotoSyncRecord>> getAllRecords() async {
    final db = await database;
    final maps = await db.query(_tableName, orderBy: 'created_time DESC');

    return maps.map((map) => PhotoSyncRecord.fromMap(map)).toList();
  }

  /// 更新记录状态
  static Future<int> updateStatus(
    String id,
    SyncStatus status, {
    String? errorMessage,
    DateTime? lastSyncTime,
    int? retryCount,
  }) async {
    final db = await database;

    final updateData = <String, dynamic>{'status': status.index};

    if (errorMessage != null) {
      updateData['error_message'] = errorMessage;
    }

    if (lastSyncTime != null) {
      updateData['last_sync_time'] = lastSyncTime.millisecondsSinceEpoch;
    }

    if (retryCount != null) {
      updateData['retry_count'] = retryCount;
    }

    return await db.update(
      _tableName,
      updateData,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 删除记录
  static Future<int> delete(String id) async {
    final db = await database;
    return await db.delete(_tableName, where: 'id = ?', whereArgs: [id]);
  }

  /// 清空所有记录
  static Future<int> clearAll() async {
    final db = await database;
    return await db.delete(_tableName);
  }

  /// 获取同步统计信息
  static Future<SyncStatistics> getStatistics() async {
    final db = await database;

    final result = await db.rawQuery('''
      SELECT 
        status,
        COUNT(*) as count,
        SUM(file_size) as total_size
      FROM $_tableName 
      GROUP BY status
    ''');

    final stats = SyncStatistics();

    for (final row in result) {
      final status = SyncStatus.values[row['status'] as int];
      final count = row['count'] as int;
      final totalSize = row['total_size'] as int? ?? 0;

      stats.updateStatus(status, count, totalSize);
    }

    return stats;
  }

  /// 清理过期的失败记录
  static Future<int> cleanupFailedRecords({int maxRetryCount = 3}) async {
    final db = await database;
    return await db.delete(
      _tableName,
      where: 'status = ? AND retry_count >= ?',
      whereArgs: [SyncStatus.failed.index, maxRetryCount],
    );
  }

  /// 关闭数据库
  static Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}

/// 同步统计信息
class SyncStatistics {
  int totalCount = 0;
  int pendingCount = 0;
  int uploadingCount = 0;
  int completedCount = 0;
  int failedCount = 0;
  int skippedCount = 0;

  int totalSize = 0;
  int pendingSize = 0;
  int uploadingSize = 0;
  int completedSize = 0;
  int failedSize = 0;
  int skippedSize = 0;

  void updateStatus(SyncStatus status, int count, int size) {
    totalCount += count;
    totalSize += size;

    switch (status) {
      case SyncStatus.pending:
        pendingCount = count;
        pendingSize = size;
        break;
      case SyncStatus.uploading:
        uploadingCount = count;
        uploadingSize = size;
        break;
      case SyncStatus.completed:
        completedCount = count;
        completedSize = size;
        break;
      case SyncStatus.failed:
        failedCount = count;
        failedSize = size;
        break;
      case SyncStatus.skipped:
        skippedCount = count;
        skippedSize = size;
        break;
    }
  }

  /// 获取完成进度（0.0 - 1.0）
  double get progress {
    if (totalCount == 0) return 1.0;
    return (completedCount + skippedCount) / totalCount;
  }

  /// 获取完成百分比
  String get progressPercent {
    return '${(progress * 100).toStringAsFixed(1)}%';
  }
}
