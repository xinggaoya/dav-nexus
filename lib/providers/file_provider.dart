import 'package:flutter/foundation.dart';
import '../models/webdav_file.dart';
import '../services/webdav_service.dart';

/// 文件管理状态管理
class FileProvider extends ChangeNotifier {
  List<WebDavFile> _files = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _currentPath = '/';
  final List<String> _pathHistory = ['/'];
  int _historyIndex = 0;

  // 选择状态
  final Set<String> _selectedFiles = {};
  bool _isSelectionMode = false;

  // 排序和视图选项
  FileSortType _sortType = FileSortType.name;
  bool _sortAscending = true;
  FileViewType _viewType = FileViewType.list;

  // Getters
  List<WebDavFile> get files => _files;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get currentPath => _currentPath;
  Set<String> get selectedFiles => _selectedFiles;
  bool get isSelectionMode => _isSelectionMode;
  FileSortType get sortType => _sortType;
  bool get sortAscending => _sortAscending;
  FileViewType get viewType => _viewType;
  bool get canGoBack => _historyIndex > 0;
  bool get canGoForward => _historyIndex < _pathHistory.length - 1;

  /// 加载目录内容
  Future<void> loadDirectory(
    WebDavService webDavService, [
    String? path,
  ]) async {
    if (_isLoading) return;

    final targetPath = path ?? _currentPath;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final files = await webDavService.listDirectory(targetPath);

      _files = files;
      _currentPath = targetPath;

      // 更新路径历史
      if (path != null) {
        _updatePathHistory(targetPath);
      }

      // 排序文件
      _sortFiles();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = '加载目录失败: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 更新路径历史
  void _updatePathHistory(String path) {
    // 如果不是当前路径，添加到历史
    if (_currentPath != path) {
      // 移除当前位置之后的历史记录
      if (_historyIndex < _pathHistory.length - 1) {
        _pathHistory.removeRange(_historyIndex + 1, _pathHistory.length);
      }

      // 添加新路径
      _pathHistory.add(path);
      _historyIndex = _pathHistory.length - 1;
    }
  }

  /// 返回上一级目录
  Future<void> goBack(WebDavService webDavService) async {
    if (!canGoBack) return;

    _historyIndex--;
    await loadDirectory(webDavService, _pathHistory[_historyIndex]);
  }

  /// 前进到下一级目录
  Future<void> goForward(WebDavService webDavService) async {
    if (!canGoForward) return;

    _historyIndex++;
    await loadDirectory(webDavService, _pathHistory[_historyIndex]);
  }

  /// 导航到父目录
  Future<void> navigateToParent(WebDavService webDavService) async {
    if (_currentPath == '/') return;

    final segments = _currentPath
        .split('/')
        .where((s) => s.isNotEmpty)
        .toList();
    if (segments.isEmpty) return;

    segments.removeLast();
    final parentPath = segments.isEmpty ? '/' : '/${segments.join('/')}/';

    await loadDirectory(webDavService, parentPath);
  }

  /// 导航到指定目录
  Future<void> navigateToDirectory(
    WebDavService webDavService,
    String path,
  ) async {
    await loadDirectory(webDavService, path);
  }

  /// 刷新当前目录
  Future<void> refresh(WebDavService webDavService) async {
    await loadDirectory(webDavService, _currentPath);
  }

  /// 排序文件
  void _sortFiles() {
    _files.sort((a, b) {
      // 文件夹总是在前面
      if (a.isDirectory && !b.isDirectory) return -1;
      if (!a.isDirectory && b.isDirectory) return 1;

      int result;
      switch (_sortType) {
        case FileSortType.name:
          result = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case FileSortType.size:
          result = a.size.compareTo(b.size);
          break;
        case FileSortType.date:
          if (a.lastModified == null && b.lastModified == null) {
            result = 0;
          } else if (a.lastModified == null) {
            result = 1;
          } else if (b.lastModified == null) {
            result = -1;
          } else {
            result = a.lastModified!.compareTo(b.lastModified!);
          }
          break;
        case FileSortType.type:
          result = a.extension.compareTo(b.extension);
          break;
      }

      return _sortAscending ? result : -result;
    });
  }

  /// 更改排序方式
  void changeSortType(FileSortType type) {
    if (_sortType == type) {
      _sortAscending = !_sortAscending;
    } else {
      _sortType = type;
      _sortAscending = true;
    }

    _sortFiles();
    notifyListeners();
  }

  /// 更改视图类型
  void changeViewType(FileViewType type) {
    _viewType = type;
    notifyListeners();
  }

  /// 选择文件
  void selectFile(String path) {
    if (_selectedFiles.contains(path)) {
      _selectedFiles.remove(path);
    } else {
      _selectedFiles.add(path);
    }

    _isSelectionMode = _selectedFiles.isNotEmpty;
    notifyListeners();
  }

  /// 全选
  void selectAll() {
    _selectedFiles.clear();
    _selectedFiles.addAll(_files.map((f) => f.path));
    _isSelectionMode = true;
    notifyListeners();
  }

  /// 取消全选
  void deselectAll() {
    _selectedFiles.clear();
    _isSelectionMode = false;
    notifyListeners();
  }

  /// 退出选择模式
  void exitSelectionMode() {
    _selectedFiles.clear();
    _isSelectionMode = false;
    notifyListeners();
  }

  /// 删除选中的文件
  Future<bool> deleteSelectedFiles(WebDavService webDavService) async {
    if (_selectedFiles.isEmpty) return false;

    try {
      for (final path in _selectedFiles) {
        await webDavService.delete(path);
      }

      // 刷新目录
      await refresh(webDavService);

      // 退出选择模式
      exitSelectionMode();

      return true;
    } catch (e) {
      _errorMessage = '删除文件失败: $e';
      notifyListeners();
      return false;
    }
  }

  /// 创建新文件夹
  Future<bool> createDirectory(WebDavService webDavService, String name) async {
    if (name.isEmpty) return false;

    try {
      final newPath = _currentPath.endsWith('/')
          ? '$_currentPath$name/'
          : '$_currentPath/$name/';

      final success = await webDavService.createDirectory(newPath);

      if (success) {
        await refresh(webDavService);
      }

      return success;
    } catch (e) {
      _errorMessage = '创建文件夹失败: $e';
      notifyListeners();
      return false;
    }
  }

  /// 上传文件
  Future<bool> uploadFile(
    WebDavService webDavService,
    String fileName,
    List<int> fileData,
  ) async {
    try {
      // 特别处理根目录的路径
      String filePath;
      if (_currentPath == '/' || _currentPath == '') {
        filePath = '/$fileName';
      } else if (_currentPath.endsWith('/')) {
        filePath = '$_currentPath$fileName';
      } else {
        filePath = '$_currentPath/$fileName';
      }

      final success = await webDavService.uploadFile(
        filePath,
        Uint8List.fromList(fileData),
      );

      if (success) {
        await refresh(webDavService);
      }

      return success;
    } catch (e) {
      _errorMessage = '上传文件失败: $e';
      notifyListeners();
      return false;
    }
  }

  /// 重命名文件
  Future<bool> renameFile(
    WebDavService webDavService,
    String oldPath,
    String newName,
  ) async {
    try {
      final file = _files.firstWhere((f) => f.path == oldPath);
      final parentPath = file.parentPath;

      // 构建新路径
      String newPath;
      if (file.isDirectory) {
        // 对于目录，确保新路径以/结尾
        newPath = parentPath.endsWith('/')
            ? '$parentPath$newName/'
            : '$parentPath/$newName/';
      } else {
        // 对于文件，不需要以/结尾
        newPath = parentPath.endsWith('/')
            ? '$parentPath$newName'
            : '$parentPath/$newName';
      }

      final success = await webDavService.move(oldPath, newPath);

      if (success) {
        await refresh(webDavService);
      }

      return success;
    } catch (e) {
      _errorMessage = '重命名失败: $e';
      notifyListeners();
      return false;
    }
  }

  /// 清除错误信息
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

/// 文件排序类型
enum FileSortType { name, size, date, type }

/// 文件视图类型
enum FileViewType { list, grid }
