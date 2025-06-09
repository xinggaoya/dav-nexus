import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/auth_provider.dart';
import '../providers/file_provider.dart';
import '../models/webdav_file.dart';
import '../constants/app_constants.dart';
import '../constants/app_theme.dart';
import '../widgets/file_thumbnail.dart';
import '../utils/file_utils.dart';
import 'file_preview_screen.dart';

/// 主页面（文件管理器）
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();

    // 初始加载根目录
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final fileProvider = Provider.of<FileProvider>(context, listen: false);

      if (authProvider.webDavService != null) {
        fileProvider.loadDirectory(authProvider.webDavService!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildNavigationBar(),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
      drawer: _buildDrawer(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(AppConstants.appName),
      actions: [
        // 搜索按钮
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () {
            // TODO: 实现搜索功能
          },
        ),

        // 视图切换按钮
        Consumer<FileProvider>(
          builder: (context, fileProvider, child) {
            return IconButton(
              icon: Icon(
                fileProvider.viewType == FileViewType.list
                    ? Icons.grid_view
                    : Icons.list,
              ),
              onPressed: () {
                fileProvider.changeViewType(
                  fileProvider.viewType == FileViewType.list
                      ? FileViewType.grid
                      : FileViewType.list,
                );
              },
            );
          },
        ),

        // 排序菜单
        PopupMenuButton<FileSortType>(
          icon: const Icon(Icons.sort),
          onSelected: (sortType) {
            Provider.of<FileProvider>(
              context,
              listen: false,
            ).changeSortType(sortType);
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: FileSortType.name, child: Text('按名称排序')),
            const PopupMenuItem(value: FileSortType.size, child: Text('按大小排序')),
            const PopupMenuItem(
              value: FileSortType.date,
              child: Text('按修改时间排序'),
            ),
            const PopupMenuItem(value: FileSortType.type, child: Text('按类型排序')),
          ],
        ),

        // 更多菜单
        PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'refresh':
                _refreshDirectory();
                break;
              case 'settings':
                Navigator.of(context).pushNamed('/settings');
                break;
              case 'logout':
                _logout();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'refresh',
              child: ListTile(
                leading: Icon(Icons.refresh),
                title: Text('刷新'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'settings',
              child: ListTile(
                leading: Icon(Icons.settings),
                title: Text('设置'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'logout',
              child: ListTile(
                leading: Icon(Icons.logout, color: AppTheme.errorColor),
                title: Text(
                  '退出登录',
                  style: TextStyle(color: AppTheme.errorColor),
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBody() {
    return Consumer<FileProvider>(
      builder: (context, fileProvider, child) {
        if (fileProvider.isLoading) {
          return const Center(
            child: SpinKitFadingCircle(color: AppTheme.primaryColor, size: 50),
          );
        }

        if (fileProvider.errorMessage != null) {
          return _buildErrorView(fileProvider.errorMessage!);
        }

        if (fileProvider.files.isEmpty) {
          return _buildEmptyView();
        }

        return RefreshIndicator(
          onRefresh: _refreshDirectory,
          child: fileProvider.viewType == FileViewType.list
              ? _buildListView(fileProvider)
              : _buildGridView(fileProvider),
        );
      },
    );
  }

  Widget _buildListView(FileProvider fileProvider) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return ListView.builder(
          itemCount: fileProvider.files.length,
          itemBuilder: (context, index) {
            final file = fileProvider.files[index];
            return Card(
              margin: const EdgeInsets.symmetric(
                horizontal: AppConstants.paddingMedium,
                vertical: 4,
              ),
              child: ListTile(
                leading: FileThumbnail(
                  file: file,
                  size: 40,
                  baseUrl: authProvider.webDavService?.baseUrl,
                  authHeader: authProvider.webDavService?.authHeader,
                ),
                title: Text(file.name),
                subtitle: file.isDirectory
                    ? null
                    : Text('${file.formattedSize} • ${file.formattedDate}'),
                onTap: () => _handleFileTap(file),
                onLongPress: () => _handleFileLongPress(file),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGridView(FileProvider fileProvider) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return GridView.builder(
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: AppConstants.paddingMedium,
            mainAxisSpacing: AppConstants.paddingMedium,
            childAspectRatio: 0.8,
          ),
          itemCount: fileProvider.files.length,
          itemBuilder: (context, index) {
            final file = fileProvider.files[index];
            return Card(
              child: InkWell(
                onTap: () => _handleFileTap(file),
                onLongPress: () => _handleFileLongPress(file),
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                child: Padding(
                  padding: const EdgeInsets.all(AppConstants.paddingMedium),
                  child: Column(
                    children: [
                      Expanded(
                        child: FileThumbnail(
                          file: file,
                          size: 80,
                          baseUrl: authProvider.webDavService?.baseUrl,
                          authHeader: authProvider.webDavService?.authHeader,
                        ),
                      ),
                      const SizedBox(height: AppConstants.paddingSmall),
                      Text(
                        file.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (!file.isDirectory &&
                          file.formattedSize.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          file.formattedSize,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppTheme.textHint),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildErrorView(String errorMessage) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
          const SizedBox(height: AppConstants.paddingMedium),
          Text('出现错误', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppConstants.paddingSmall),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.paddingLarge,
            ),
            child: Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
            ),
          ),
          const SizedBox(height: AppConstants.paddingLarge),
          ElevatedButton(onPressed: _refreshDirectory, child: const Text('重试')),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 64, color: AppTheme.textHint),
          const SizedBox(height: AppConstants.paddingMedium),
          Text('文件夹为空', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppConstants.paddingSmall),
          Text(
            '这个文件夹没有任何内容',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: _showAddMenu,
      child: const Icon(Icons.add),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          return Column(
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppTheme.primaryColor, AppTheme.primaryVariant],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.cloud, color: Colors.white, size: 48),
                    const SizedBox(height: AppConstants.paddingMedium),
                    Text(
                      AppConstants.appName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppConstants.paddingSmall),
                    Text(
                      authProvider.username,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.home),
                      title: const Text('主页'),
                      onTap: () {
                        Navigator.pop(context);
                        _navigateToRoot();
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.refresh),
                      title: const Text('刷新'),
                      onTap: () {
                        Navigator.pop(context);
                        _refreshDirectory();
                      },
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.photo_library),
                      title: const Text('相册同步'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context).pushNamed('/photo_sync');
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.settings),
                      title: const Text('设置'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context).pushNamed('/settings');
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text('关于'),
                      onTap: () {
                        Navigator.pop(context);
                        _showAboutDialog();
                      },
                    ),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: AppTheme.errorColor),
                title: const Text(
                  '退出登录',
                  style: TextStyle(color: AppTheme.errorColor),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _logout();
                },
              ),
            ],
          );
        },
      ),
    );
  }

  /// 构建导航栏（面包屑导航）
  Widget _buildNavigationBar() {
    return Consumer<FileProvider>(
      builder: (context, fileProvider, child) {
        return Container(
          height: 56,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              // 返回按钮
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: fileProvider.canGoBack ? () => _goBack() : null,
                tooltip: '返回上一级',
              ),

              // 前进按钮
              IconButton(
                icon: const Icon(Icons.arrow_forward),
                onPressed: fileProvider.canGoForward
                    ? () => _goForward()
                    : null,
                tooltip: '前进',
              ),

              // 上级目录按钮
              IconButton(
                icon: const Icon(Icons.arrow_upward),
                onPressed: fileProvider.currentPath != '/'
                    ? () => _navigateToParent()
                    : null,
                tooltip: '上级目录',
              ),

              const SizedBox(width: 8),

              // 面包屑路径
              Expanded(child: _buildBreadcrumbs(fileProvider)),

              // 主页按钮
              IconButton(
                icon: const Icon(Icons.home),
                onPressed: () => _navigateToRoot(),
                tooltip: '返回主页',
              ),

              // 更多导航选项
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                tooltip: '更多选项',
                onSelected: (value) {
                  switch (value) {
                    case 'refresh':
                      _refreshDirectory();
                      break;
                    case 'show_path':
                      _showFullPathDialog(fileProvider);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'refresh',
                    child: ListTile(
                      leading: Icon(Icons.refresh),
                      title: Text('刷新当前目录'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'show_path',
                    child: ListTile(
                      leading: Icon(Icons.folder_open),
                      title: Text('显示完整路径'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建面包屑导航
  Widget _buildBreadcrumbs(FileProvider fileProvider) {
    // 获取显示用的路径段（过滤掉技术前缀）
    final displaySegments = _getDisplayPathSegments(fileProvider.currentPath);

    if (displaySegments.isEmpty) {
      return GestureDetector(
        onTap: () => _navigateToRoot(),
        child: const Text(
          '根目录',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // 根目录
          _buildBreadcrumbItem('根目录', _getRootPath()),

          // 路径分隔符和各级目录
          for (int i = 0; i < displaySegments.length; i++) ...[
            Icon(
              Icons.chevron_right,
              size: 16,
              color: Theme.of(
                context,
              ).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
            ),
            _buildBreadcrumbItem(
              displaySegments[i],
              _getRealPathFromDisplaySegments(
                displaySegments.sublist(0, i + 1),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 获取用于显示的路径段（过滤技术前缀）
  List<String> _getDisplayPathSegments(String currentPath) {
    final pathSegments = currentPath
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList();

    // 如果第一个段是 'dav'，则跳过它（这是WebDAV的技术前缀）
    if (pathSegments.isNotEmpty && pathSegments.first == 'dav') {
      return pathSegments.sublist(1);
    }

    return pathSegments;
  }

  /// 从显示路径段还原真实路径
  String _getRealPathFromDisplaySegments(List<String> displaySegments) {
    if (displaySegments.isEmpty) {
      return _getRootPath();
    }

    // 检查当前路径是否有 'dav' 前缀
    final currentSegments = Provider.of<FileProvider>(
      context,
      listen: false,
    ).currentPath.split('/').where((segment) => segment.isNotEmpty).toList();

    if (currentSegments.isNotEmpty && currentSegments.first == 'dav') {
      // 需要添加 'dav' 前缀
      return '/dav/${displaySegments.join('/')}/';
    } else {
      // 不需要前缀
      return '/${displaySegments.join('/')}/';
    }
  }

  /// 获取根路径
  String _getRootPath() {
    final currentSegments = Provider.of<FileProvider>(
      context,
      listen: false,
    ).currentPath.split('/').where((segment) => segment.isNotEmpty).toList();

    // 如果当前路径有 'dav' 前缀，根路径也应该有
    if (currentSegments.isNotEmpty && currentSegments.first == 'dav') {
      return '/dav/';
    } else {
      return '/';
    }
  }

  /// 构建面包屑项目
  Widget _buildBreadcrumbItem(String label, String path) {
    return InkWell(
      onTap: () => _navigateToPath(path),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 120), // 限制最大宽度
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).primaryColor,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis, // 超长文本显示省略号
          maxLines: 1,
        ),
      ),
    );
  }

  // 事件处理方法
  void _handleFileTap(file) {
    final fileProvider = Provider.of<FileProvider>(context, listen: false);

    if (file.isDirectory) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.webDavService != null) {
        fileProvider.navigateToDirectory(
          authProvider.webDavService!,
          file.path,
        );
      }
    } else {
      // 检查是否为可预览文件
      if (FileUtils.isPreviewableFile(file)) {
        _previewFile(file);
      } else {
        _showFileOptions(file);
      }
    }
  }

  void _handleFileLongPress(file) {
    // 长按显示操作菜单
    if (!file.isDirectory) {
      _showFileOptions(file);
    } else {
      // 对于文件夹，还是进入选择模式
      final fileProvider = Provider.of<FileProvider>(context, listen: false);
      fileProvider.selectFile(file.path);
    }
  }

  /// 预览文件
  void _previewFile(WebDavFile file) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FilePreviewScreen(
          file: file,
          authHeader: authProvider.webDavService?.authHeader,
          baseUrl: authProvider.webDavService?.baseUrl,
          onDownload: () {
            Navigator.pop(context);
            _downloadFile(file);
          },
          onRename: () {
            Navigator.pop(context);
            _showRenameDialog(file);
          },
          onDelete: () {
            Navigator.pop(context);
            _confirmDelete(file);
          },
        ),
      ),
    );
  }

  Future<void> _refreshDirectory() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final fileProvider = Provider.of<FileProvider>(context, listen: false);

    if (authProvider.webDavService != null) {
      await fileProvider.refresh(authProvider.webDavService!);
    }
  }

  void _navigateToRoot() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final fileProvider = Provider.of<FileProvider>(context, listen: false);

    if (authProvider.webDavService != null) {
      fileProvider.navigateToDirectory(authProvider.webDavService!, '/');
    }
  }

  // 新增的导航方法
  /// 返回上一级（历史记录）
  void _goBack() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final fileProvider = Provider.of<FileProvider>(context, listen: false);

    if (authProvider.webDavService != null) {
      fileProvider.goBack(authProvider.webDavService!);
    }
  }

  /// 前进到下一级（历史记录）
  void _goForward() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final fileProvider = Provider.of<FileProvider>(context, listen: false);

    if (authProvider.webDavService != null) {
      fileProvider.goForward(authProvider.webDavService!);
    }
  }

  /// 导航到父级目录
  void _navigateToParent() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final fileProvider = Provider.of<FileProvider>(context, listen: false);

    if (authProvider.webDavService != null) {
      fileProvider.navigateToParent(authProvider.webDavService!);
    }
  }

  /// 导航到指定路径
  void _navigateToPath(String path) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final fileProvider = Provider.of<FileProvider>(context, listen: false);

    if (authProvider.webDavService != null) {
      fileProvider.navigateToDirectory(authProvider.webDavService!, path);
    }
  }

  /// 显示完整路径对话框
  void _showFullPathDialog(FileProvider fileProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('当前路径'),
        content: SelectableText(
          fileProvider.currentPath,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
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

  void _showAddMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => _buildAddMenu(),
    );
  }

  Widget _buildAddMenu() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: const Text('新建文件夹'),
            onTap: () {
              Navigator.pop(context);
              _showCreateFolderDialog();
            },
          ),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('上传文件'),
            onTap: () {
              Navigator.pop(context);
              _uploadFile();
            },
          ),
        ],
      ),
    );
  }

  void _showCreateFolderDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建文件夹'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '请输入文件夹名称',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(context);
                _createFolder(name);
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  Future<void> _createFolder(String name) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final fileProvider = Provider.of<FileProvider>(context, listen: false);

    if (authProvider.webDavService != null) {
      final success = await fileProvider.createDirectory(
        authProvider.webDavService!,
        name,
      );

      if (success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('文件夹创建成功')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(fileProvider.errorMessage ?? '创建文件夹失败'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _uploadFile() async {
    try {
      // 显示加载对话框
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在选择文件...'),
            ],
          ),
        ),
      );

      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.any,
      );

      // 关闭加载对话框
      if (mounted) Navigator.pop(context);

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        // 详细检查文件有效性
        print('Selected file: ${file.name}');
        print('File size: ${file.size}');
        print('File bytes length: ${file.bytes?.length}');
        print('File path: ${file.path}');

        if (file.name.isNotEmpty && (file.bytes != null || file.path != null)) {
          await _uploadSelectedFile(file);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '选择的文件无效：名称=${file.name}, 大小=${file.size}, 字节=${file.bytes?.length}',
              ),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      // 确保关闭加载对话框
      if (mounted) Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('选择文件失败: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _uploadSelectedFile(PlatformFile file) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final fileProvider = Provider.of<FileProvider>(context, listen: false);

    if (authProvider.webDavService == null) return;

    // 显示上传进度对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('正在上传 "${file.name}"...'),
          ],
        ),
      ),
    );

    try {
      List<int> fileData;

      if (file.bytes != null) {
        fileData = file.bytes!;
      } else if (file.path != null) {
        // 如果字节数据不可用，尝试从文件路径读取
        try {
          final fileFromPath = File(file.path!);
          fileData = await fileFromPath.readAsBytes();
        } catch (e) {
          throw Exception('无法读取文件数据: $e');
        }
      } else {
        throw Exception('文件数据不可用');
      }

      final success = await fileProvider.uploadFile(
        authProvider.webDavService!,
        file.name,
        fileData,
      );

      // 关闭上传对话框
      if (mounted) Navigator.pop(context);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('文件 "${file.name}" 上传成功'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(fileProvider.errorMessage ?? '文件上传失败'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      // 确保关闭上传对话框
      if (mounted) Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('文件上传失败: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _downloadFile(WebDavFile file) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.webDavService == null) return;

    // 显示下载进度对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('正在下载 "${file.name}"...'),
          ],
        ),
      ),
    );

    try {
      final fileData = await authProvider.webDavService!.downloadFile(
        file.path,
      );

      // 关闭下载对话框
      if (mounted) Navigator.pop(context);

      // TODO: 这里可以实现将文件保存到设备存储
      // 目前只是显示下载完成的消息
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('文件 "${file.name}" 下载完成 (${fileData.length} 字节)'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: '查看',
            onPressed: () {
              // TODO: 可以添加文件预览功能
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('文件预览功能开发中...')));
            },
          ),
        ),
      );
    } catch (e) {
      // 确保关闭下载对话框
      if (mounted) Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('文件下载失败: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  void _showFileOptions(file) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              file.name,
              style: Theme.of(context).textTheme.titleMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppConstants.paddingMedium),
            if (!file.isDirectory) ...[
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('下载'),
                onTap: () {
                  Navigator.pop(context);
                  _downloadFile(file);
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('重命名'),
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog(file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: AppTheme.errorColor),
              title: const Text(
                '删除',
                style: TextStyle(color: AppTheme.errorColor),
              ),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(file);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(WebDavFile file) {
    final controller = TextEditingController(text: file.name);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '请输入新名称',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != file.name) {
                Navigator.pop(context);
                _renameFile(file, newName);
              }
            },
            child: const Text('重命名'),
          ),
        ],
      ),
    );
  }

  Future<void> _renameFile(WebDavFile file, String newName) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final fileProvider = Provider.of<FileProvider>(context, listen: false);

    if (authProvider.webDavService != null) {
      try {
        final success = await fileProvider.renameFile(
          authProvider.webDavService!,
          file.path,
          newName,
        );

        if (success) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('重命名成功')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(fileProvider.errorMessage ?? '重命名失败'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('重命名失败: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete(file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('您确定要删除 "${file.name}" 吗？此操作无法撤销。'),
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
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final fileProvider = Provider.of<FileProvider>(context, listen: false);

      if (authProvider.webDavService != null) {
        try {
          final success = await authProvider.webDavService!.delete(file.path);
          if (success) {
            await fileProvider.refresh(authProvider.webDavService!);
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('删除成功')));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('删除失败'),
                backgroundColor: AppTheme.errorColor,
              ),
            );
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('删除失败: $e'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: AppConstants.appName,
      applicationVersion: AppConstants.appVersion,
      applicationIcon: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.primaryColor, AppTheme.primaryVariant],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.cloud, color: Colors.white, size: 24),
      ),
      children: [const Text('一个现代化的WebDAV云盘客户端')],
    );
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认退出'),
        content: const Text('您确定要退出登录吗？'),
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
            child: const Text('退出'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.logout();
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }
}
