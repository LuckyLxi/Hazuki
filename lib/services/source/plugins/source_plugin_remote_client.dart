import 'dart:convert';

import 'package:dio/dio.dart';

import '../../preferences/software_update_source.dart';
import 'source_plugin_models.dart';
import 'source_plugin_repository.dart';

/// 下载进度回调；[total] 未知时为 -1。
typedef SourcePluginDownloadProgress = void Function(int received, int total);

/// Resolves plugin repositories and fetches their indexes and scripts.
class SourcePluginRemoteClient {
  SourcePluginRemoteClient({
    Future<List<int>> Function(Uri url)? download,
    required Future<SoftwareUpdateSource> Function() loadUpdateSource,
  }) : _download = download == null
           ? _downloadBytes
           // 注入的下载函数不提供分块信息，进度保持未知。
           : ((url, {onProgress}) => download(url)),
       _loadUpdateSource = loadUpdateSource;

  final Future<List<int>> Function(
    Uri url, {
    SourcePluginDownloadProgress? onProgress,
  })
  _download;
  final Future<SoftwareUpdateSource> Function() _loadUpdateSource;

  /// Resolve a public GitHub repo, a tree/blob URL, or an HTTPS JSON URL.
  Future<Uri> resolveRepository(
    String address, {
    String? branch,
    String path = 'plugins.json',
  }) async {
    final uri = Uri.tryParse(address.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const SourcePluginException('plugin_invalid_repository');
    }
    if (uri.host != 'github.com') return uri;
    final parts = uri.pathSegments;
    if (parts.length < 2 || !isPluginPath(path)) {
      throw const SourcePluginException('plugin_invalid_repository');
    }
    final owner = parts[0];
    final repo = parts[1].replaceFirst(RegExp(r'\.git$'), '');
    var selectedBranch = branch;
    var selectedPath = path;
    if (parts.length > 3 && (parts[2] == 'tree' || parts[2] == 'blob')) {
      selectedBranch ??= parts[3];
      final branchParts = selectedBranch.split('/');
      final branchLength =
          parts.skip(3).take(branchParts.length).join('/') == selectedBranch
          ? branchParts.length
          : 1;
      if (parts.length > 3 + branchLength) {
        selectedPath = parts.skip(3 + branchLength).join('/');
        if (parts[2] == 'tree') selectedPath = '$selectedPath/$path';
      }
    }
    if (selectedBranch == null || selectedBranch.isEmpty) {
      final info = jsonDecode(
        utf8.decode(
          await _download(Uri.https('api.github.com', '/repos/$owner/$repo')),
        ),
      );
      selectedBranch = (info as Map)['default_branch'] as String?;
      if (selectedBranch == null || selectedBranch.isEmpty) {
        throw const SourcePluginException('plugin_repository_not_found');
      }
    }
    return Uri(
      scheme: 'https',
      host: 'raw.githubusercontent.com',
      pathSegments: [owner, repo, selectedBranch, ...selectedPath.split('/')],
    );
  }

  Future<List<int>> downloadIndex(Uri url) async =>
      _download(resolveSourcePluginIndexUrl(url, await _loadUpdateSource()));

  /// 内置仓库的插件包跟随更新源下载；所选线路失败时回退到索引原始地址。
  Future<List<int>> downloadPackage(
    String repository,
    Uri url, {
    SourcePluginDownloadProgress? onProgress,
  }) async {
    if (repository != sourcePluginsRepositoryUrl) {
      return _download(url, onProgress: onProgress);
    }
    final routed = resolveSourcePluginPackageUrl(
      url,
      await _loadUpdateSource(),
    );
    if (routed == url) return _download(url, onProgress: onProgress);
    try {
      return await _download(routed, onProgress: onProgress);
    } catch (_) {
      return _download(url, onProgress: onProgress);
    }
  }

  /// 网络失败时带上底层原因，避免只显示 `DioException [unknown]: null`。
  static Future<List<int>> _downloadBytes(
    Uri url, {
    SourcePluginDownloadProgress? onProgress,
  }) async {
    try {
      return await _downloadBytesOnce(url, onProgress);
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      final cause = error.error ?? error.message;
      throw SourcePluginException(
        'plugin_download_failed',
        [
          error.type.name,
          if (status != null) 'HTTP $status',
          if (cause != null) '$cause',
        ].join(': '),
      );
    }
  }

  static Future<List<int>> _downloadBytesOnce(
    Uri url,
    SourcePluginDownloadProgress? onProgress,
  ) async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 60),
      ),
    );
    try {
      final response = await dio.get<ResponseBody>(
        url.toString(),
        options: Options(responseType: ResponseType.stream),
      );
      // 压缩传输时响应头长度与解压后的字节数不一致，此时按未知处理。
      final encoded = response.headers.value('content-encoding') != null;
      final total = encoded ? -1 : (response.data!.contentLength);
      final result = <int>[];
      await for (final bytes in response.data!.stream) {
        result.addAll(bytes);
        if (result.length > 8 * 1024 * 1024) {
          throw const SourcePluginException('plugin_download_too_large');
        }
        onProgress?.call(result.length, total);
      }
      return result;
    } finally {
      dio.close(force: true);
    }
  }
}
