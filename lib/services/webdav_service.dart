import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'dart:convert';
import '../models/webdav_file.dart';
import 'package:xml/xml.dart' as xml;

/// WebDAV服务类
class WebDavService {
  final String baseUrl;
  final String username;
  final String password;

  late Dio _dio;
  late String _authHeader;

  WebDavService({
    required this.baseUrl,
    required this.username,
    required this.password,
  }) {
    _dio = Dio();
    _setupDio();
  }

  /// 获取认证头
  String get authHeader => _authHeader;

  /// 配置Dio
  void _setupDio() {
    final credentials = base64Encode(utf8.encode('$username:$password'));
    _authHeader = 'Basic $credentials';

    _dio.options.headers['Authorization'] = _authHeader;
    _dio.options.headers['User-Agent'] = 'DAV Nexus/1.0.0';
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
  }

  /// 测试连接
  Future<bool> testConnection() async {
    try {
      final response = await _dio.request(
        baseUrl,
        options: Options(
          method: 'PROPFIND',
          headers: {
            'Depth': '0',
            'Content-Type': 'application/xml; charset=utf-8',
          },
          validateStatus: (status) {
            // 接受更多的状态码作为有效响应
            return status != null && status >= 200 && status < 400;
          },
        ),
      );

      return response.statusCode == 207 ||
          response.statusCode == 200 ||
          response.statusCode == 404;
    } catch (e) {
      return false;
    }
  }

  /// 列出目录内容
  Future<List<WebDavFile>> listDirectory(String path) async {
    try {
      // 对于根目录，确保使用正确的路径
      String requestPath = path;
      if (path.isEmpty || path == '/') {
        requestPath = '/';
      }

      final url = _buildUrl(requestPath);

      final propfindBody = '''<?xml version="1.0" encoding="utf-8"?>
<D:propfind xmlns:D="DAV:">
  <D:prop>
    <D:displayname/>
    <D:getcontentlength/>
    <D:getcontenttype/>
    <D:getlastmodified/>
    <D:getetag/>
    <D:resourcetype/>
  </D:prop>
</D:propfind>''';

      final response = await _dio.request(
        url,
        options: Options(
          method: 'PROPFIND',
          headers: {
            'Depth': '1',
            'Content-Type': 'application/xml; charset=utf-8',
          },
          validateStatus: (status) {
            // 接受更多的状态码作为有效响应
            return status != null && status >= 200 && status < 300;
          },
        ),
        data: propfindBody,
      );

      if (response.statusCode != 207 && response.statusCode != 200) {
        throw Exception('Failed to list directory: ${response.statusCode}');
      }

      return _parseMultiStatus(response.data.toString(), requestPath);
    } catch (e) {
      throw Exception('Error listing directory: $e');
    }
  }

  /// 解析PROPFIND响应
  List<WebDavFile> _parseMultiStatus(String responseBody, String requestPath) {
    final files = <WebDavFile>[];

    try {
      final document = xml.XmlDocument.parse(responseBody);
      final responses = document.findAllElements('response', namespace: 'DAV:');

      for (final response in responses) {
        final href = response
            .findElements('href', namespace: 'DAV:')
            .first
            .innerText;

        // 安全地解码URL，如果解码失败则使用原始href
        String decodedHref;
        try {
          decodedHref = Uri.decodeFull(href);
        } catch (e) {
          decodedHref = href; // 使用原始href，常见于emoji等特殊字符
        }

        // 更准确地过滤当前目录
        final normalizedHref = _normalizePath(decodedHref);
        final normalizedRequestPath = _normalizePath(requestPath);

        // 跳过当前目录（完全匹配或末尾带斜杠的匹配）
        if (normalizedHref == normalizedRequestPath ||
            normalizedHref ==
                normalizedRequestPath.replaceAll(RegExp(r'/+$'), '') ||
            normalizedRequestPath ==
                normalizedHref.replaceAll(RegExp(r'/+$'), '')) {
          continue;
        }

        // 额外检查：如果是根目录，跳过基础路径本身
        if (requestPath == '/' &&
            (decodedHref.endsWith('/dav/') || decodedHref == '/dav')) {
          continue;
        }

        final propstat = response
            .findElements('propstat', namespace: 'DAV:')
            .first;
        final status = propstat
            .findElements('status', namespace: 'DAV:')
            .first
            .innerText;

        // 只处理成功的响应
        if (!status.contains('200 OK')) continue;

        final prop = propstat.findElements('prop', namespace: 'DAV:').first;

        // 解析文件信息
        final file = _parseFileFromProp(decodedHref, prop);
        if (file != null) {
          files.add(file);
        }
      }
    } catch (e) {
      print('Error parsing multistatus: $e');
    }

    // 去重（基于路径）
    final uniqueFiles = <String, WebDavFile>{};
    for (final file in files) {
      uniqueFiles[file.path] = file;
    }

    final result = uniqueFiles.values.toList();

    // 排序：文件夹在前，然后按名称排序
    result.sort((a, b) {
      if (a.isDirectory && !b.isDirectory) return -1;
      if (!a.isDirectory && b.isDirectory) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return result;
  }

  /// 从prop元素解析文件信息
  WebDavFile? _parseFileFromProp(String href, xml.XmlElement prop) {
    try {
      // 获取文件名
      String name = href.split('/').where((s) => s.isNotEmpty).last;
      if (name.isEmpty) return null;

      // 安全地解码文件名
      try {
        name = Uri.decodeFull(name);
      } catch (e) {
        // 如果解码失败，保持原始名称（常见于emoji等特殊字符）
      }

      // 检查是否为目录
      final resourceType = prop
          .findElements('resourcetype', namespace: 'DAV:')
          .firstOrNull;
      final isDirectory =
          resourceType
              ?.findElements('collection', namespace: 'DAV:')
              .isNotEmpty ??
          false;

      // 解析文件大小
      int size = 0;
      final contentLengthElement = prop
          .findElements('getcontentlength', namespace: 'DAV:')
          .firstOrNull;
      if (contentLengthElement != null) {
        size = int.tryParse(contentLengthElement.innerText) ?? 0;
      }

      // 解析修改时间
      DateTime? lastModified;
      final lastModifiedElement = prop
          .findElements('getlastmodified', namespace: 'DAV:')
          .firstOrNull;
      if (lastModifiedElement != null) {
        try {
          lastModified = HttpDate.parse(lastModifiedElement.innerText);
        } catch (e) {
          // 尝试其他格式
          try {
            lastModified = DateTime.parse(lastModifiedElement.innerText);
          } catch (e) {
            // 忽略解析错误
          }
        }
      }

      // 解析内容类型
      final contentTypeElement = prop
          .findElements('getcontenttype', namespace: 'DAV:')
          .firstOrNull;
      final contentType = contentTypeElement?.innerText;

      // 解析ETag
      final etagElement = prop
          .findElements('getetag', namespace: 'DAV:')
          .firstOrNull;
      final etag = etagElement?.innerText;

      return WebDavFile(
        name: name,
        path: href,
        isDirectory: isDirectory,
        size: size,
        lastModified: lastModified,
        contentType: contentType,
        etag: etag,
      );
    } catch (e) {
      print('Error parsing file from prop: $e');
      return null;
    }
  }

  /// 下载文件
  Future<Uint8List> downloadFile(String path) async {
    try {
      final url = _buildUrl(path);
      final response = await _dio.get(
        url,
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to download file: ${response.statusCode}');
      }

      return Uint8List.fromList(response.data);
    } catch (e) {
      throw Exception('Error downloading file: $e');
    }
  }

  /// 上传文件
  Future<bool> uploadFile(String path, Uint8List data) async {
    try {
      final url = _buildUrl(path);

      final response = await _dio.put(
        url,
        data: data,
        options: Options(
          headers: {
            'Content-Type': 'application/octet-stream',
            'Content-Length': data.length.toString(),
          },
          validateStatus: (status) {
            // 接受更多的状态码
            return status != null && status >= 200 && status < 400;
          },
        ),
      );

      return response.statusCode == 201 ||
          response.statusCode == 204 ||
          response.statusCode == 200;
    } catch (e) {
      throw Exception('Error uploading file: $e');
    }
  }

  /// 创建目录
  Future<bool> createDirectory(String path) async {
    try {
      final url = _buildUrl(path);
      final response = await _dio.request(
        url,
        options: Options(method: 'MKCOL'),
      );

      return response.statusCode == 201 ||
          response.statusCode == 405; // 405表示目录已存在
    } catch (e) {
      throw Exception('Error creating directory: $e');
    }
  }

  /// 删除文件或目录
  Future<bool> delete(String path) async {
    try {
      final url = _buildUrl(path);
      final response = await _dio.delete(
        url,
        options: Options(
          validateStatus: (status) {
            // 接受更多的状态码
            return status != null && status >= 200 && status < 500;
          },
        ),
      );

      // 成功的状态码
      if (response.statusCode == 204 || response.statusCode == 200) {
        return true;
      }

      // 文件不存在，也认为是成功（已经被删除了）
      if (response.statusCode == 404) {
        return true;
      }

      // 405 Method Not Allowed - 尝试备用删除方法
      if (response.statusCode == 405) {
        return await _deleteByMove(path);
      }

      // 403 Forbidden - 权限不足
      if (response.statusCode == 403) {
        throw Exception('没有权限删除此文件');
      }

      // 其他错误状态码
      throw Exception('删除失败: HTTP ${response.statusCode}');
    } catch (e) {
      if (e is Exception && e.toString().contains('没有权限删除此文件')) {
        rethrow;
      }

      // 如果DELETE完全失败，尝试备用方法
      try {
        return await _deleteByMove(path);
      } catch (moveError) {
        throw Exception('删除操作失败: $e');
      }
    }
  }

  /// 备用删除方法：通过移动文件到垃圾箱路径实现删除
  Future<bool> _deleteByMove(String path) async {
    try {
      // 生成一个垃圾箱路径
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = path.split('/').last;
      final trashPath = '/.trash_$timestamp/$fileName';

      // 先尝试创建垃圾箱目录
      try {
        await createDirectory('/.trash_$timestamp/');
      } catch (e) {
        // 忽略创建目录的错误，可能已经存在
      }

      // 移动文件到垃圾箱
      final success = await move(path, trashPath);

      if (success) {
        // 延迟一段时间后尝试删除垃圾箱目录（清理）
        Future.delayed(const Duration(seconds: 5), () async {
          try {
            await _dio.delete(
              _buildUrl('/.trash_$timestamp/'),
              options: Options(
                validateStatus: (status) => true, // 忽略所有错误
              ),
            );
          } catch (e) {
            // 忽略清理错误
          }
        });
      }

      return success;
    } catch (e) {
      throw Exception('备用删除方法失败: $e');
    }
  }

  /// 移动/重命名文件或目录
  Future<bool> move(String from, String to) async {
    try {
      final fromUrl = _buildUrl(from);
      final toUrl = _buildUrl(to);

      print('移动操作 - fromUrl: $fromUrl'); // 调试日志
      print('移动操作 - toUrl: $toUrl'); // 调试日志

      // 先检查目标路径是否已存在
      final toExists = await fileExists(to);
      if (toExists) {
        print('目标路径已存在，无法移动'); // 调试日志
        throw Exception('目标路径已存在，请使用其他名称');
      }

      // 判断是否为文件夹操作，针对文件夹可能需要特殊处理
      final isDirectory = from.endsWith('/') || to.endsWith('/');
      print('是否为文件夹操作: $isDirectory'); // 调试日志

      // 对于文件夹，可能需要确保路径末尾有斜杠
      String finalToUrl = toUrl;
      if (isDirectory && !finalToUrl.endsWith('/')) {
        finalToUrl = '$finalToUrl/';
        print('调整后的目标URL: $finalToUrl'); // 调试日志
      }

      try {
        final response = await _dio.request(
          fromUrl,
          options: Options(
            method: 'MOVE',
            headers: {
              'Destination': finalToUrl,
              'Overwrite': 'F', // 不覆盖已存在的内容
            },
            validateStatus: (status) {
              // 接受更多的状态码，包括409冲突，便于更好地处理错误
              return status != null &&
                  (status >= 200 && status < 300 ||
                      status == 409 ||
                      status == 412);
            },
          ),
        );

        print('移动操作响应状态码: ${response.statusCode}'); // 调试日志

        if (response.statusCode == 409 || response.statusCode == 412) {
          print('冲突：目标路径可能已存在 - ${response.statusCode}'); // 调试日志
          throw Exception('目标路径已存在或被锁定，请使用其他名称');
        }

        return response.statusCode == 201 ||
            response.statusCode == 204 ||
            response.statusCode == 200;
      } catch (requestError) {
        print('请求异常: $requestError'); // 调试日志

        // 对于文件夹操作，如果失败，尝试备用方法
        if (isDirectory) {
          print('尝试使用备用方法移动文件夹'); // 调试日志
          return await _moveDirectoryFallback(from, to);
        }

        rethrow;
      }
    } catch (e) {
      print('移动操作异常: $e'); // 调试日志
      throw Exception('Error moving: $e');
    }
  }

  /// 文件夹移动的备用方法
  /// 某些WebDAV服务器对文件夹操作有特殊要求，这是一个备用实现
  Future<bool> _moveDirectoryFallback(String from, String to) async {
    try {
      print('执行文件夹移动备用方法 - from: $from, to: $to'); // 调试日志

      // 1. 确保目标文件夹不存在
      final toExists = await fileExists(to);
      if (toExists) {
        throw Exception('目标文件夹已存在');
      }

      // 2. 创建目标文件夹
      final createSuccess = await createDirectory(to);
      if (!createSuccess) {
        throw Exception('无法创建目标文件夹');
      }

      print('已创建目标文件夹: $to'); // 调试日志

      // 3. 列出源文件夹中的内容
      final files = await listDirectory(from);
      print('源文件夹内文件数量: ${files.length}'); // 调试日志

      // 4. 逐个复制/移动文件
      for (final file in files) {
        if (file.path == from) continue; // 跳过文件夹自身

        final relativePath = file.path.substring(from.length);
        final newPath = to + relativePath;

        print('移动子项 - 从: ${file.path}, 到: $newPath'); // 调试日志

        if (file.isDirectory) {
          // 递归处理子文件夹
          await _moveDirectoryFallback(file.path, newPath);
        } else {
          // 移动文件
          await move(file.path, newPath);
        }
      }

      // 5. 删除原文件夹（可选，取决于需求）
      // 在所有内容移动成功后，才删除源文件夹
      await delete(from);

      return true;
    } catch (e) {
      print('文件夹移动备用方法异常: $e'); // 调试日志
      throw Exception('备用移动方法失败: $e');
    }
  }

  /// 复制文件或目录
  Future<bool> copy(String from, String to) async {
    try {
      final fromUrl = _buildUrl(from);
      final toUrl = _buildUrl(to);

      final response = await _dio.request(
        fromUrl,
        options: Options(
          method: 'COPY',
          headers: {'Destination': toUrl, 'Overwrite': 'F'},
        ),
      );

      return response.statusCode == 201 || response.statusCode == 204;
    } catch (e) {
      throw Exception('Error copying: $e');
    }
  }

  /// 检查文件或目录是否存在
  Future<bool> fileExists(String path) async {
    try {
      final url = _buildUrl(path);

      final response = await _dio.request(
        url,
        options: Options(
          method: 'HEAD',
          validateStatus: (status) {
            // HEAD请求：200表示存在，404表示不存在
            return status != null && (status == 200 || status == 404);
          },
        ),
      );

      return response.statusCode == 200;
    } catch (e) {
      // 如果HEAD请求失败，尝试使用PROPFIND
      try {
        final propfindBody = '''<?xml version="1.0" encoding="utf-8"?>
<D:propfind xmlns:D="DAV:">
  <D:prop>
    <D:resourcetype/>
  </D:prop>
</D:propfind>''';

        final response = await _dio.request(
          _buildUrl(path),
          options: Options(
            method: 'PROPFIND',
            headers: {
              'Depth': '0',
              'Content-Type': 'application/xml; charset=utf-8',
            },
            validateStatus: (status) {
              return status != null && (status == 207 || status == 404);
            },
          ),
          data: propfindBody,
        );

        return response.statusCode == 207;
      } catch (e) {
        return false;
      }
    }
  }

  /// 构建完整的URL
  String _buildUrl(String path) {
    print('构建URL开始 - 原始路径: $path'); // 调试日志

    final cleanPath = _normalizePath(path);
    print('规范化后路径: $cleanPath'); // 调试日志

    // 确保基础URL正确格式化
    String formattedBaseUrl = baseUrl;
    if (!formattedBaseUrl.endsWith('/')) {
      formattedBaseUrl += '/';
    }

    print('格式化后的基础URL: $formattedBaseUrl'); // 调试日志

    // 检查路径是否已经包含/dav/前缀
    if (cleanPath.startsWith('/dav/')) {
      // 如果路径已经包含/dav/，则组合域名部分
      final uri = Uri.parse(formattedBaseUrl);
      final result = '${uri.scheme}://${uri.host}${cleanPath}';
      print('包含/dav/前缀的URL: $result'); // 调试日志
      return result;
    }

    // 对于根路径（仅仅是"/"），返回基础URL
    if (cleanPath == '/') {
      print('根路径URL: $formattedBaseUrl'); // 调试日志
      return formattedBaseUrl;
    }

    // 对于根目录下的文件（如"/filename.jpg"），需要特殊处理
    if (cleanPath.startsWith('/') && !cleanPath.contains('/', 1)) {
      // 这是根目录下的文件，移除开头的斜杠
      String finalPath = cleanPath.substring(1);
      final result = '$formattedBaseUrl$finalPath';
      print('根目录下文件URL: $result'); // 调试日志
      return result;
    }

    // 移除路径开头的斜杠，因为基础URL已经以斜杠结尾
    String finalPath = cleanPath.startsWith('/')
        ? cleanPath.substring(1)
        : cleanPath;

    final result = '$formattedBaseUrl$finalPath';
    print('最终构建的URL: $result'); // 调试日志
    return result;
  }

  /// 规范化路径
  String _normalizePath(String path) {
    print('规范化路径开始 - 原始路径: $path'); // 调试日志

    if (path.isEmpty) {
      print('空路径，返回: /'); // 调试日志
      return '/';
    }

    String normalizedPath = path;
    if (!normalizedPath.startsWith('/')) {
      normalizedPath = '/$normalizedPath';
    }

    // 移除重复的斜杠
    normalizedPath = normalizedPath.replaceAll(RegExp(r'/+'), '/');

    print('规范化后的路径: $normalizedPath'); // 调试日志
    return normalizedPath;
  }

  /// 释放资源
  void dispose() {
    _dio.close();
  }
}
