import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/services.dart';
import 'package:flutter_qjs/flutter_qjs.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/api.dart' show KeyParameter;
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/ecb.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/hazuki_models.dart';

part 'source/account_session_capability.dart';
part 'source/check_in_capability.dart';
part 'source/comments_capability.dart';
part 'source/debug_capability.dart';
part 'source/explore_capability.dart';
part 'source/category_capability.dart';
part 'source/comic_details_capability.dart';
part 'source/favorites_capability.dart';
part 'source/image_cache_capability.dart';
part 'source/image_prepare_capability.dart';
part 'source/line_settings.dart';
part 'source/source_loader_capability.dart';

const _jmSourceUrls = [
  'https://raw.githubusercontent.com/venera-app/venera-configs/main/jm.js',
  'https://fastly.jsdelivr.net/gh/venera-app/venera-configs@main/jm.js',
  'https://gcore.jsdelivr.net/gh/venera-app/venera-configs@main/jm.js',
  'https://cdn.jsdelivr.net/gh/venera-app/venera-configs@main/jm.js',
];

const _sourceIndexUrls = [
  'https://cdn.jsdelivr.net/gh/venera-app/venera-configs@main/index.json',
  'https://gcore.jsdelivr.net/gh/venera-app/venera-configs@main/index.json',
  'https://fastly.jsdelivr.net/gh/venera-app/venera-configs@main/index.json',
  'https://raw.githubusercontent.com/venera-app/venera-configs/main/index.json',
];

const _bundledInitAssetPath = 'assets/init.js';

enum DailyCheckInStatus {
  success,
  alreadyCheckedIn,
  skipped,
}

class DailyCheckInResult {
  const DailyCheckInResult._(this.status, [this.message]);

  const DailyCheckInResult.success([String? message])
    : this._(DailyCheckInStatus.success, message);

  const DailyCheckInResult.alreadyCheckedIn([String? message])
    : this._(DailyCheckInStatus.alreadyCheckedIn, message);

  const DailyCheckInResult.skipped([String? message])
    : this._(DailyCheckInStatus.skipped, message);

  final DailyCheckInStatus status;
  final String? message;

  bool get isSuccess => status == DailyCheckInStatus.success;
  bool get isAlreadyCheckedIn => status == DailyCheckInStatus.alreadyCheckedIn;
  bool get isSkipped => status == DailyCheckInStatus.skipped;
}

class HazukiSourceService {
  HazukiSourceService._();

  static final HazukiSourceService instance = HazukiSourceService._();

  // 设置连接超时和接收超时，防止网络请求永久挂起
  final Dio _dio = Dio(
    BaseOptions(
      responseType: ResponseType.plain,
      validateStatus: (status) => true,
      connectTimeout: const Duration(seconds: 35),
      receiveTimeout: const Duration(seconds: 90),
      sendTimeout: const Duration(seconds: 35),
    ),
  );

  FlutterQjs? _engine;
  SharedPreferences? _prefs;
  Future<void>? _initFuture;

  String _statusText = 'source_initializing';
  SourceMeta? _sourceMeta;
  Map<String, dynamic>? _favoritesDebugCache;
  bool _isWarmingUpFavoritesDebug = false;
  bool _isRefreshingSource = false;
  final List<Map<String, dynamic>> _recentNetworkLogs = [];
  int _networkLogDedupedCount = 0;
  Map<String, dynamic>? _lastLoginDebugInfo;
  Map<String, dynamic>? _lastSourceVersionDebugInfo;
  final LinkedHashMap<String, Uint8List> _imageBytesCache =
      LinkedHashMap<String, Uint8List>();
  final Map<String, Future<Uint8List>> _imageDownloadInFlight =
      <String, Future<Uint8List>>{};
  final LinkedHashMap<String, ComicDetailsData> _comicDetailsMemoryCache =
      LinkedHashMap<String, ComicDetailsData>();
  List<ExploreSection>? _exploreSectionsMemoryCache;
  DateTime? _exploreSectionsMemoryCachedAt;
  Directory? _imageCacheDir;
  Directory? _comicDetailsCacheDir;
  Directory? _discoverCacheDir;
  DateTime? _lastReloginAt;

  static const String _cacheMaxBytesKey = 'image_cache_max_bytes';
  static const String _cacheAutoCleanModeKey = 'image_cache_auto_clean_mode';
  static const String _cacheLastAutoCleanAtKey =
      'image_cache_last_auto_clean_at';

  static const int _defaultCacheMaxBytes = 400 * 1024 * 1024;
  static const String _defaultAutoCleanMode = 'size_overflow';
  static const Duration _discoverCacheTtl = Duration(days: 1);
  static const double _cacheOverflowTrimTargetRatio = 0.1;

  String get statusText => _statusText;
  SourceMeta? get sourceMeta => _sourceMeta;
  bool get isInitialized => _engine != null && _sourceMeta != null;

  Future<void> init({
    void Function(int received, int total)? onSourceDownloadProgress,
  }) async {
    final inFlight = _initFuture;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final future = _initInternal(
      onSourceDownloadProgress: onSourceDownloadProgress,
    );
    _initFuture = future;
    await future;
  }

  Future<void> ensureInitialized() async {
    if (isInitialized) {
      return;
    }

    final inFlight = _initFuture;
    if (inFlight == null) {
      await init();
    } else {
      await inFlight;
    }

    if (isInitialized) {
      return;
    }

    // First init can fail silently (statusText records details). Retry once
    // here so callers that need source runtime get a deterministic result.
    _initFuture = null;
    await init();

    if (!isInitialized) {
      throw Exception('source_not_initialized:$_statusText');
    }
  }

  Future<void> _initInternal({
    void Function(int received, int total)? onSourceDownloadProgress,
  }) async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _configureDioCookieBridge();
      await _initImageCache();
      await _initDiscoverCache();
      final result = await _downloadOrLoadSourceFiles(
        onProgress: onSourceDownloadProgress,
      );
      final meta = await _loadSourceMetadata(result.initFile, result.jmFile);
      _sourceMeta = meta;
      _statusText =
          '${result.message}|${meta.name}|${meta.key}|${meta.version}';
    } catch (e) {
      _statusText = 'source_init_failed:$e';
    }
  }

  Future<SourceVersionCheckResult?> checkJmSourceVersionFromCloud() async {
    final sourceDir = await _getSourceStorageDirectory();
    final jmFile = File('${sourceDir.path}/jm.js');
    if (!await jmFile.exists()) {
      _lastSourceVersionDebugInfo = {
        'checkedAt': DateTime.now().toIso8601String(),
        'sourceDir': sourceDir.path,
        'localJmExists': false,
        'outcome': 'local_jm_missing',
      };
      return null;
    }

    final localVersion = await _readJmVersionFromFile(jmFile);
    final remoteVersionDirect = await _resolveRemoteJmVersion();
    if (remoteVersionDirect != null && remoteVersionDirect.isNotEmpty) {
      final hasUpdate = _isVersionGreater(remoteVersionDirect, localVersion);
      _lastSourceVersionDebugInfo = {
        'checkedAt': DateTime.now().toIso8601String(),
        'sourceDir': sourceDir.path,
        'localJmExists': true,
        'localVersion': localVersion,
        'remoteVersion': remoteVersionDirect,
        'hasUpdate': hasUpdate,
        'remoteVersionSource':
            _lastSourceVersionDebugInfo?['resolvedFrom'] ?? 'unknown',
        'outcome': hasUpdate ? 'update_available' : 'no_update',
      };
      return SourceVersionCheckResult(
        localVersion: localVersion,
        remoteVersion: remoteVersionDirect,
        hasUpdate: hasUpdate,
      );
    }
    final indexRaw = await _downloadFromUrls(_sourceIndexUrls);
    if (indexRaw == null || indexRaw.trim().isEmpty) {
      _lastSourceVersionDebugInfo = {
        'checkedAt': DateTime.now().toIso8601String(),
        'sourceDir': sourceDir.path,
        'localJmExists': true,
        'localVersion': localVersion,
        'outcome': 'index_download_empty',
      };
      return null;
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(indexRaw);
    } catch (_) {
      _lastSourceVersionDebugInfo = {
        'checkedAt': DateTime.now().toIso8601String(),
        'sourceDir': sourceDir.path,
        'localJmExists': true,
        'localVersion': localVersion,
        'outcome': 'index_json_decode_failed',
      };
      return null;
    }
    if (decoded is! List) {
      _lastSourceVersionDebugInfo = {
        'checkedAt': DateTime.now().toIso8601String(),
        'sourceDir': sourceDir.path,
        'localJmExists': true,
        'localVersion': localVersion,
        'outcome': 'index_json_not_list',
      };
      return null;
    }

    String? remoteVersion;
    for (final item in decoded) {
      if (item is! Map) {
        continue;
      }
      final map = Map<String, dynamic>.from(item);
      final name = map['name']?.toString().trim();
      final key = map['key']?.toString().trim().toLowerCase();
      final fileName = map['fileName']?.toString().trim().toLowerCase();
      final isTarget = name == '禁漫天堂' || key == 'jm' || fileName == 'jm.js';
      if (!isTarget) {
        continue;
      }
      remoteVersion = map['version']?.toString().trim();
      break;
    }

    if (remoteVersion == null || remoteVersion.isEmpty) {
      _lastSourceVersionDebugInfo = {
        'checkedAt': DateTime.now().toIso8601String(),
        'sourceDir': sourceDir.path,
        'localJmExists': true,
        'localVersion': localVersion,
        'outcome': 'remote_version_not_found_in_index',
      };
      return null;
    }

    final hasUpdate = _isVersionGreater(remoteVersion, localVersion);
    _lastSourceVersionDebugInfo = {
      'checkedAt': DateTime.now().toIso8601String(),
      'sourceDir': sourceDir.path,
      'localJmExists': true,
      'localVersion': localVersion,
      'remoteVersion': remoteVersion,
      'hasUpdate': hasUpdate,
      'remoteVersionSource': 'index_fallback_parse',
      'outcome': hasUpdate ? 'update_available' : 'no_update',
    };

    return SourceVersionCheckResult(
      localVersion: localVersion,
      remoteVersion: remoteVersion,
      hasUpdate: hasUpdate,
    );
  }

  Future<bool> downloadJmSourceAndReload({
    void Function(int received, int total)? onProgress,
  }) async {
    final sourceDir = await _getSourceStorageDirectory();
    if (!await sourceDir.exists()) {
      await sourceDir.create(recursive: true);
    }
    final initFile = File('${sourceDir.path}/init.js');
    final jmFile = File('${sourceDir.path}/jm.js');

    if (!await initFile.exists()) {
      final bundledInit = await rootBundle.loadString(_bundledInitAssetPath);
      await initFile.writeAsString(bundledInit);
    }

    final jmScript = await _downloadFromUrlsWithProgress(
      _jmSourceUrls,
      onProgress: onProgress,
    );
    if (jmScript == null || jmScript.trim().isEmpty) {
      return false;
    }

    await jmFile.writeAsString(jmScript);

    _lastReloginAt = null;
    _favoritesDebugCache = null;
    _exploreSectionsMemoryCache = null;
    _exploreSectionsMemoryCachedAt = null;
    _sourceMeta = null;

    final result = await _loadSourceMetadata(initFile, jmFile);
    _sourceMeta = result;
    _statusText =
        'source_reloaded|${result.name}|${result.key}|${result.version}';
    if (isLogged) {
      await _tryReloginFromStoredAccount(force: true);
    }
    return true;
  }

  Future<bool> hasLocalJmSourceFile() async {
    final sourceDir = await _getSourceStorageDirectory();
    final jmFile = File('${sourceDir.path}/jm.js');
    return jmFile.exists();
  }

  Future<Directory> _getSourceStorageDirectory() async {
    if (Platform.isAndroid) {
      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        return Directory('${externalDir.path}/comic_source');
      }
    }

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null) {
        return Directory('${downloadsDir.path}/hazuki_source_test');
      }
    }

    final documentsDir = await getApplicationDocumentsDirectory();
    return Directory('${documentsDir.path}/comic_source');
  }

  Future<bool> refreshSourceOnNetworkRecovery() async {
    if (_isRefreshingSource) {
      return false;
    }
    _isRefreshingSource = true;
    try {
      _lastReloginAt = null;
      _favoritesDebugCache = null;
      _exploreSectionsMemoryCache = null;
      _exploreSectionsMemoryCachedAt = null;
      _sourceMeta = null;
      final result = await _downloadOrLoadSourceFiles();
      final meta = await _loadSourceMetadata(result.initFile, result.jmFile);
      _sourceMeta = meta;
      _statusText =
          '${result.message}|${meta.name}|${meta.key}|${meta.version}';
      if (isLogged) {
        await _tryReloginFromStoredAccount(force: true);
      }
      return true;
    } catch (_) {
      return false;
    } finally {
      _isRefreshingSource = false;
    }
  }

  Future<SearchComicsResult> searchComics({
    required String keyword,
    required int page,
    String order = 'mr',
  }) async {
    final engine = _engine;
    if (engine == null) {
      throw Exception('source_not_initialized');
    }

    final normalizedKeyword = keyword.trim();
    if (normalizedKeyword.isEmpty) {
      return const SearchComicsResult(comics: [], maxPage: 0);
    }

    final normalizedPage = page < 1 ? 1 : page;
    final normalizedOrder = order.trim().isEmpty ? 'mr' : order.trim();

    final hasSearch = _asBool(engine.evaluate('!!this.__hazuki_source.search'));
    final hasSearchLoad = _asBool(
      engine.evaluate('!!this.__hazuki_source.search?.load'),
    );
    if (!hasSearch || !hasSearchLoad) {
      throw Exception('search_not_supported');
    }

    final optionsArg = jsonEncode([normalizedOrder]);
    final dynamic result = engine.evaluate(
      'this.__hazuki_source.search.load(${jsonEncode(normalizedKeyword)}, $optionsArg, $normalizedPage)',
      name: 'source_search.js',
    );
    final dynamic resolved = await _awaitJsResult(result);

    if (resolved is! Map) {
      return const SearchComicsResult(comics: [], maxPage: null);
    }

    final map = Map<String, dynamic>.from(resolved);
    final comicsRaw = map['comics'];
    final List<ExploreComic> comics = comicsRaw is List
        ? _parseExploreComics(comicsRaw)
        : const <ExploreComic>[];

    final maxPageRaw = map['maxPage'];
    final maxPage = switch (maxPageRaw) {
      int value => value,
      num value => value.toInt(),
      _ => int.tryParse(maxPageRaw?.toString() ?? ''),
    };

    return SearchComicsResult(comics: comics, maxPage: maxPage);
  }

  dynamic _handleJsMessage(dynamic message) {
    if (message is! Map) {
      return null;
    }

    final map = Map<String, dynamic>.from(message);
    final method = map['method']?.toString();
    dynamic result;

    switch (method) {
      case 'http':
        result = _handleHttpRequest(map);
        break;
      case 'cookie':
        result = _handleCookieOperation(map);
        break;
      case 'load_data':
        result = _loadSourceData(
          map['key']?.toString() ?? '',
          map['data_key']?.toString() ?? '',
        );
        break;
      case 'save_data':
        result = _saveSourceData(
          map['key']?.toString() ?? '',
          map['data_key']?.toString() ?? '',
          map['data'],
        );
        break;
      case 'delete_data':
        result = _deleteSourceData(
          map['key']?.toString() ?? '',
          map['data_key']?.toString() ?? '',
        );
        break;
      case 'load_setting':
        result = _loadSourceSetting(
          map['key']?.toString() ?? '',
          map['setting_key']?.toString() ?? '',
        );
        break;
      case 'isLogged':
        result = _loadAccountDataSync() != null;
        break;
      case 'delay':
        final ms = map['time'] is num ? (map['time'] as num).toInt() : 0;
        result = Future<void>.delayed(Duration(milliseconds: ms));
        break;
      case 'random':
        result = _handleRandom(map);
        break;
      case 'convert':
        result = _handleConvert(map);
        break;
      case 'getLocale':
        result = 'zh_CN';
        break;
      case 'getPlatform':
        result = Platform.operatingSystem;
        break;
      case 'log':
        result = null;
        break;
      default:
        throw UnsupportedError('暂未实现的 JS 方法: $method');
    }

    if (result is Future) {
      result = result.whenComplete(() {
        _engine?.port.sendPort.send(null);
      });
    }
    return result;
  }

  Future<Map<String, dynamic>> _handleHttpRequest(
    Map<String, dynamic> request,
  ) async {
    Response<dynamic>? response;
    String? error;
    final startedAt = DateTime.now();

    final method = (request['http_method']?.toString() ?? 'GET').toUpperCase();
    var url = request['url']?.toString() ?? '';

    // Bypass CDN cache automatically for API GET requests silently
    if (method == 'GET' && url.isNotEmpty) {
      final connector = url.contains('?') ? '&' : '?';
      url =
          '$url${connector}_hazuki_nocache=${DateTime.now().millisecondsSinceEpoch}';
    }

    final headers = Map<String, dynamic>.from(request['headers'] as Map? ?? {});
    final bytes = request['bytes'] == true;
    final data = request['data'];

    try {
      response = await _dio.request<dynamic>(
        url,
        data: data,
        options: Options(
          method: method,
          responseType: bytes ? ResponseType.bytes : ResponseType.plain,
          headers: headers,
          extra: {'skipNetworkDebugLog': true},
        ),
      );
    } catch (e) {
      error = e.toString();
    } finally {
      final responseHeadersForLog = <String, dynamic>{};
      response?.headers.forEach((name, values) {
        responseHeadersForLog[name] = values.join(',');
      });
      _appendNetworkLog(
        method: method,
        url: url,
        statusCode: response?.statusCode,
        error: error,
        startedAt: startedAt,
        source: 'js_http',
        requestHeaders: Map<String, dynamic>.from(headers),
        requestData: data,
        responseHeaders: responseHeadersForLog,
        responseBody: response?.data,
      );
    }

    final responseHeaders = <String, String>{};
    response?.headers.forEach((name, values) {
      responseHeaders[name] = values.join(',');
    });

    return {
      'status': response?.statusCode,
      'headers': responseHeaders,
      'body': response?.data,
      'error': error,
    };
  }

  void _configureDioCookieBridge() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.extra['hazukiStartedAt'] = DateTime.now();
          final cookieHeader = _buildCookieHeader(options.uri.toString());
          if (cookieHeader != null && cookieHeader.isNotEmpty) {
            final existing = options.headers['cookie'];
            if (existing is String && existing.trim().isNotEmpty) {
              options.headers['cookie'] = '$existing; $cookieHeader';
            } else {
              options.headers['cookie'] = cookieHeader;
            }
          }
          handler.next(options);
        },
        onResponse: (response, handler) async {
          final requestUrl = response.requestOptions.uri.toString();
          await _saveCookiesFromHeaders(requestUrl, response.headers.map);

          final skipLog =
              response.requestOptions.extra['skipNetworkDebugLog'] == true;
          if (!skipLog) {
            final startedAt =
                response.requestOptions.extra['hazukiStartedAt'] is DateTime
                ? response.requestOptions.extra['hazukiStartedAt'] as DateTime
                : DateTime.now();
            final responseHeadersForLog = <String, dynamic>{};
            response.headers.forEach((name, values) {
              responseHeadersForLog[name] = values.join(',');
            });
            _appendNetworkLog(
              method: response.requestOptions.method,
              url: requestUrl,
              statusCode: response.statusCode,
              error: null,
              startedAt: startedAt,
              source: 'dio_direct',
              requestHeaders: Map<String, dynamic>.from(
                response.requestOptions.headers,
              ),
              requestData: response.requestOptions.data,
              responseHeaders: responseHeadersForLog,
              responseBody: response.data,
            );
          }
          handler.next(response);
        },
        onError: (error, handler) {
          final options = error.requestOptions;
          final skipLog = options.extra['skipNetworkDebugLog'] == true;
          if (!skipLog) {
            final startedAt = options.extra['hazukiStartedAt'] is DateTime
                ? options.extra['hazukiStartedAt'] as DateTime
                : DateTime.now();
            final responseHeadersForLog = <String, dynamic>{};
            final response = error.response;
            response?.headers.forEach((name, values) {
              responseHeadersForLog[name] = values.join(',');
            });
            _appendNetworkLog(
              method: options.method,
              url: options.uri.toString(),
              statusCode: response?.statusCode,
              error: error.toString(),
              startedAt: startedAt,
              source: 'dio_direct',
              requestHeaders: Map<String, dynamic>.from(options.headers),
              requestData: options.data,
              responseHeaders: responseHeadersForLog,
              responseBody: response?.data,
            );
          }
          handler.next(error);
        },
      ),
    );

    _dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        return HttpClient();
      },
    );
  }

  Future<dynamic> _handleCookieOperation(Map<String, dynamic> request) async {
    final fn = request['function']?.toString();
    final rawUrl = request['url']?.toString();
    if (rawUrl == null || rawUrl.isEmpty) {
      return null;
    }

    final url = _normalizeCookieUrl(rawUrl);

    switch (fn) {
      case 'set':
        final list = request['cookies'];
        if (list is List) {
          final cookies = list
              .whereType<Map>()
              .map((e) => _Cookie.fromMap(Map<String, dynamic>.from(e)))
              .toList();
          await _setCookies(url, cookies);
        }
        return null;
      case 'get':
        return _getCookies(url).map((e) => e.toMap()).toList();
      case 'delete':
        await _deleteCookies(url);
        return null;
      default:
        return null;
    }
  }

  dynamic _handleRandom(Map<String, dynamic> request) {
    final min = request['min'];
    final max = request['max'];
    final type = request['type']?.toString() ?? 'int';
    final minNum = min is num ? min : 0;
    final maxNum = max is num ? max : 1;
    if (type == 'double') {
      return minNum + (maxNum - minNum) * DateTime.now().microsecond / 1000000;
    }
    final range = (maxNum - minNum).toInt();
    if (range <= 0) {
      return minNum.toInt();
    }
    return minNum.toInt() + (DateTime.now().microsecond % range);
  }

  dynamic _handleConvert(Map<String, dynamic> request) {
    final type = request['type']?.toString() ?? '';
    final isEncode = request['isEncode'] == true;
    final isString = request['isString'] == true;
    final value = request['value'];

    switch (type) {
      case 'utf8':
        return isEncode
            ? utf8.encode((value ?? '').toString())
            : utf8.decode(_toBytes(value));
      case 'base64':
        return isEncode
            ? base64Encode(_toBytes(value))
            : base64Decode((value ?? '').toString());
      case 'md5':
        return Uint8List.fromList(md5.convert(_toBytes(value)).bytes);
      case 'sha1':
        return Uint8List.fromList(sha1.convert(_toBytes(value)).bytes);
      case 'sha256':
        return Uint8List.fromList(sha256.convert(_toBytes(value)).bytes);
      case 'sha512':
        return Uint8List.fromList(sha512.convert(_toBytes(value)).bytes);
      case 'hmac':
        final keyBytes = _toBytes(request['key']);
        final valueBytes = _toBytes(value);
        final hashType = request['hash']?.toString() ?? 'md5';
        final digest = Hmac(switch (hashType) {
          'md5' => md5,
          'sha1' => sha1,
          'sha256' => sha256,
          'sha512' => sha512,
          _ => md5,
        }, keyBytes).convert(valueBytes);
        if (isString) {
          return digest.toString();
        }
        return Uint8List.fromList(digest.bytes);
      case 'aes-ecb':
        final key = _toBytes(request['key']);
        final bytes = _toBytes(value);
        final cipher = ECBBlockCipher(AESEngine())
          ..init(isEncode, KeyParameter(key));
        final result = Uint8List(bytes.length);
        var offset = 0;
        while (offset < bytes.length) {
          offset += cipher.processBlock(bytes, offset, result, offset);
        }
        return result;
      case 'gbk':
      case 'aes-cbc':
      case 'aes-cfb':
      case 'aes-ofb':
      case 'rsa':
        throw UnsupportedError('convert 暂不支持: $type');
      default:
        return value;
    }
  }

  Uint8List _toBytes(dynamic value) {
    if (value is Uint8List) {
      return value;
    }
    if (value is List<int>) {
      return Uint8List.fromList(value);
    }
    if (value is List) {
      return Uint8List.fromList(value.map((e) => (e as num).toInt()).toList());
    }
    if (value is String) {
      return Uint8List.fromList(utf8.encode(value));
    }
    return Uint8List(0);
  }

  Future<String?> _downloadFromUrls(
    List<String> urls, {
    String source = 'source_fetch',
  }) async {
    if (urls.isEmpty) {
      return null;
    }

    Future<String?> requestOnce(String url) async {
      final startedAt = DateTime.now();
      try {
        final response = await _dio.get<String>(
          url,
          options: Options(
            responseType: ResponseType.plain,
            headers: {'cache-control': 'no-cache'},
          ),
        );
        _appendNetworkLog(
          source: source,
          method: 'GET',
          url: url,
          statusCode: response.statusCode,
          error: null,
          startedAt: startedAt,
          responseHeaders: response.headers.map,
          responseBody: response.data,
        );
        if (response.statusCode == 200 &&
            (response.data?.isNotEmpty ?? false)) {
          return response.data;
        }
      } catch (e) {
        _appendNetworkLog(
          source: source,
          method: 'GET',
          url: url,
          statusCode: null,
          error: e.toString(),
          startedAt: startedAt,
        );
      }
      return null;
    }

    final completer = Completer<String?>();
    var finished = false;

    void tryComplete(String? value) {
      if (finished || value == null) {
        return;
      }
      finished = true;
      completer.complete(value);
    }

    Future<void> runAll() async {
      final futures = urls.map((url) async {
        final result = await requestOnce(url);
        if (result != null) {
          tryComplete(result);
        }
      }).toList();
      await Future.wait(futures);
      if (!finished) {
        completer.complete(null);
      }
    }

    runAll();
    return completer.future;
  }

  Future<String?> _downloadFromUrlsWithProgress(
    List<String> urls, {
    void Function(int received, int total)? onProgress,
    String source = 'source_download',
  }) async {
    for (final url in urls) {
      final startedAt = DateTime.now();
      try {
        final response = await _dio.get<String>(
          url,
          options: Options(
            responseType: ResponseType.plain,
            headers: {'cache-control': 'no-cache'},
          ),
          onReceiveProgress: onProgress,
        );
        _appendNetworkLog(
          source: source,
          method: 'GET',
          url: url,
          statusCode: response.statusCode,
          error: null,
          startedAt: startedAt,
          responseHeaders: response.headers.map,
          responseBody: response.data,
        );
        if (response.statusCode == 200 &&
            (response.data?.isNotEmpty ?? false)) {
          return response.data;
        }
      } catch (e) {
        _appendNetworkLog(
          source: source,
          method: 'GET',
          url: url,
          statusCode: null,
          error: e.toString(),
          startedAt: startedAt,
        );
      }
    }
    return null;
  }

  Future<String> _readJmVersionFromFile(File jmFile) async {
    final content = await jmFile.readAsString();
    return _extractSourceVersion(content);
  }

  Future<String?> _resolveRemoteJmVersion() async {
    final indexRaw = await _downloadFromUrls(
      _sourceIndexUrls,
      source: 'source_version_index',
    );
    if (indexRaw != null && indexRaw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(indexRaw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is! Map) {
              continue;
            }
            final map = Map<String, dynamic>.from(item);
            final key = map['key']?.toString().trim().toLowerCase();
            final fileName = map['fileName']?.toString().trim().toLowerCase();
            if (key != 'jm' && fileName != 'jm.js') {
              continue;
            }
            final version = map['version']?.toString().trim();
            if (version != null && version.isNotEmpty) {
              _lastSourceVersionDebugInfo = {
                'checkedAt': DateTime.now().toIso8601String(),
                'resolvedFrom': 'index_json',
                'matchedKey': key,
                'matchedFileName': fileName,
                'remoteVersion': version,
              };
              return version;
            }
          }
        }
      } catch (_) {}
    }

    final remoteScript = await _downloadFromUrls(
      _jmSourceUrls,
      source: 'source_version_jm_script',
    );
    if (remoteScript == null || remoteScript.trim().isEmpty) {
      _lastSourceVersionDebugInfo = {
        'checkedAt': DateTime.now().toIso8601String(),
        'resolvedFrom': 'failed',
        'outcome': 'remote_script_empty',
      };
      return null;
    }
    final version = _extractSourceVersion(remoteScript);
    _lastSourceVersionDebugInfo = {
      'checkedAt': DateTime.now().toIso8601String(),
      'resolvedFrom': 'jm_script',
      'remoteVersion': version,
    };
    return version;
  }

  String _extractSourceVersion(String script) {
    final match = RegExp(
      "version\\s*=\\s*['\\\"]([^'\\\"]+)['\\\"]",
    ).firstMatch(script);
    return match?.group(1) ?? '0.0.0';
  }

  bool _isVersionGreater(String a, String b) {
    final pa = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final pb = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final len = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < len; i++) {
      final va = i < pa.length ? pa[i] : 0;
      final vb = i < pb.length ? pb[i] : 0;
      if (va > vb) {
        return true;
      }
      if (va < vb) {
        return false;
      }
    }
    return false;
  }

  String _extractSourceClassName(String script) {
    final regex = RegExp(
      r'class\s+([A-Za-z_][A-Za-z0-9_]*)\s+extends\s+ComicSource',
    );
    final match = regex.firstMatch(script);
    if (match == null) {
      throw Exception('jm.js 格式无效：未找到 extends ComicSource 的类定义');
    }
    return match.group(1)!;
  }

  bool _asBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      return value == 'true' || value == '1';
    }
    return false;
  }

  int? _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  Map<String, dynamic> _parseSettingsDefaultMap(dynamic raw) {
    if (raw is! Map) {
      return {};
    }

    final defaults = <String, dynamic>{};
    final settingMap = Map<String, dynamic>.from(raw);
    for (final entry in settingMap.entries) {
      final value = entry.value;
      if (value is Map && value.containsKey('default')) {
        defaults[entry.key] = value['default'];
      }
    }
    return defaults;
  }

  Map<String, dynamic> _loadSourceStore(String sourceKey) {
    final prefs = _prefs;
    if (prefs == null || sourceKey.isEmpty) {
      return {};
    }

    final raw = prefs.getString('source_data_$sourceKey');
    if (raw == null || raw.isEmpty) {
      return {};
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return {};
  }

  Future<void> _saveSourceStore(
    String sourceKey,
    Map<String, dynamic> store,
  ) async {
    final prefs = _prefs;
    if (prefs == null || sourceKey.isEmpty) {
      return;
    }
    await prefs.setString('source_data_$sourceKey', jsonEncode(store));
  }

  dynamic _loadSourceData(String sourceKey, String dataKey) {
    if (sourceKey.isEmpty || dataKey.isEmpty) {
      return null;
    }
    final store = _loadSourceStore(sourceKey);
    return store[dataKey];
  }

  Future<void> _saveSourceData(
    String sourceKey,
    String dataKey,
    dynamic data,
  ) async {
    if (sourceKey.isEmpty || dataKey.isEmpty) {
      return;
    }
    final store = _loadSourceStore(sourceKey);
    store[dataKey] = data;
    await _saveSourceStore(sourceKey, store);
  }

  Future<void> _saveSourceSetting(
    String sourceKey,
    String settingKey,
    dynamic value,
  ) async {
    if (sourceKey.isEmpty || settingKey.isEmpty) {
      return;
    }
    final store = _loadSourceStore(sourceKey);
    final settingsRaw = store['settings'];
    final settings = settingsRaw is Map
        ? Map<String, dynamic>.from(settingsRaw)
        : <String, dynamic>{};
    settings[settingKey] = value;
    store['settings'] = settings;
    await _saveSourceStore(sourceKey, store);
  }

  Future<void> _deleteSourceData(String sourceKey, String dataKey) async {
    if (sourceKey.isEmpty || dataKey.isEmpty) {
      return;
    }
    final store = _loadSourceStore(sourceKey);
    store.remove(dataKey);
    await _saveSourceStore(sourceKey, store);
  }

  dynamic _loadSourceSetting(String sourceKey, String settingKey) {
    if (sourceKey.isEmpty || settingKey.isEmpty) {
      return null;
    }

    final store = _loadSourceStore(sourceKey);
    final settings = store['settings'];
    if (settings is Map && settings.containsKey(settingKey)) {
      return settings[settingKey];
    }

    if (_sourceMeta?.key == sourceKey) {
      return _sourceMeta?.settingsDefaults[settingKey];
    }

    return null;
  }

  List<String>? _loadAccountDataSync() {
    final key = _sourceMeta?.key;
    if (key == null) {
      return null;
    }

    final accountData = _loadSourceData(key, 'account');
    if (accountData is List && accountData.length >= 2) {
      return [accountData[0].toString(), accountData[1].toString()];
    }
    return null;
  }

  List<_Cookie> _loadCookieStore() {
    final prefs = _prefs;
    if (prefs == null) {
      return [];
    }

    final raw = prefs.getString('cookie_store_v1');
    if (raw == null || raw.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => _Cookie.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> _saveCookieStore(List<_Cookie> cookies) async {
    final prefs = _prefs;
    if (prefs == null) {
      return;
    }
    await prefs.setString(
      'cookie_store_v1',
      jsonEncode(cookies.map((e) => e.toMap()).toList()),
    );
  }

  List<_Cookie> _getCookies(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return [];
    }

    final all = _loadCookieStore();
    final now = DateTime.now().millisecondsSinceEpoch;

    return all.where((cookie) {
      if (cookie.isExpired(now)) {
        return false;
      }
      return cookie.matches(uri);
    }).toList();
  }

  Future<void> _setCookies(String url, List<_Cookie> cookies) async {
    final uri = Uri.tryParse(url);
    if (uri == null || cookies.isEmpty) {
      return;
    }

    final all = _loadCookieStore();
    for (final cookie in cookies) {
      final normalized = cookie.withFallbackDomain(uri.host);
      all.removeWhere(
        (existing) =>
            existing.name == normalized.name &&
            existing.domain == normalized.domain &&
            existing.path == normalized.path,
      );
      all.add(normalized);

      if (normalized.domain.startsWith('.')) {
        final hostDomain = normalized.domain.substring(1);
        all.removeWhere(
          (existing) =>
              existing.name == normalized.name &&
              existing.path == normalized.path &&
              existing.domain == hostDomain,
        );
      } else {
        all.removeWhere(
          (existing) =>
              existing.name == normalized.name &&
              existing.path == normalized.path &&
              existing.domain == '.${normalized.domain}',
        );
      }
    }

    await _saveCookieStore(all);
  }

  Future<void> _deleteCookies(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return;
    }

    final all = _loadCookieStore();
    all.removeWhere((cookie) => cookie.matches(uri));
    await _saveCookieStore(all);
  }

  String? _buildCookieHeader(String url) {
    final cookies = _getCookies(url);
    if (cookies.isEmpty) {
      return null;
    }

    final selected = <String, _Cookie>{};
    for (final cookie in cookies) {
      final current = selected[cookie.name];
      if (current == null) {
        selected[cookie.name] = cookie;
        continue;
      }

      final cookieDomain = cookie.domain;
      final currentDomain = current.domain;
      final cookieStartsWithDot = cookieDomain.startsWith('.');
      final currentStartsWithDot = currentDomain.startsWith('.');

      if (!cookieStartsWithDot && currentStartsWithDot) {
        selected[cookie.name] = cookie;
      } else if (cookieStartsWithDot == currentStartsWithDot &&
          cookieDomain.length > currentDomain.length) {
        selected[cookie.name] = cookie;
      }
    }

    return selected.values.map((e) => '${e.name}=${e.value}').join('; ');
  }

  Future<void> _saveCookiesFromHeaders(
    String url,
    Map<String, List<String>> headers,
  ) async {
    final setCookies = headers.entries
        .where((entry) => entry.key.toLowerCase() == 'set-cookie')
        .expand((entry) => entry.value)
        .toList();

    if (setCookies.isEmpty) {
      return;
    }

    final parsed = <_Cookie>[];
    for (final raw in setCookies) {
      final segments = _splitSetCookieHeader(raw);
      for (final segment in segments) {
        final cookie = _Cookie.parseSetCookie(segment, url);
        if (cookie != null) {
          parsed.add(cookie);
        }
      }
    }
    await _setCookies(url, parsed);
  }

  String _normalizeCookieUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasScheme) {
      return trimmed;
    }
    return 'https://$trimmed';
  }

  List<String> _splitSetCookieHeader(String raw) {
    if (!raw.contains(',')) {
      return [raw];
    }

    final parts = raw.split(RegExp(r',(?=\s*[^;,\s]+=)'));
    return parts.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }
}

class _SourceLoadResult {
  const _SourceLoadResult({
    required this.initFile,
    required this.jmFile,
    required this.message,
  });

  final File initFile;
  final File jmFile;
  final String message;
}

class SourceVersionCheckResult {
  const SourceVersionCheckResult({
    required this.localVersion,
    required this.remoteVersion,
    required this.hasUpdate,
  });

  final String localVersion;
  final String remoteVersion;
  final bool hasUpdate;
}

class _Cookie {
  const _Cookie({
    required this.name,
    required this.value,
    required this.domain,
    required this.path,
    this.expiresAt,
  });

  final String name;
  final String value;
  final String domain;
  final String path;
  final int? expiresAt;

  bool isExpired(int now) {
    if (expiresAt == null) {
      return false;
    }
    return expiresAt! <= now;
  }

  bool matches(Uri uri) {
    final requestHost = uri.host.toLowerCase();
    final normalizedDomain = domain.toLowerCase();
    final cookieDomain = normalizedDomain.startsWith('.')
        ? normalizedDomain.substring(1)
        : normalizedDomain;
    final domainMatch =
        requestHost == cookieDomain || requestHost.endsWith('.$cookieDomain');
    if (!domainMatch) {
      return false;
    }

    final requestPath = uri.path.isEmpty ? '/' : uri.path;
    final cookiePath = path.isEmpty ? '/' : path;
    return requestPath.startsWith(cookiePath);
  }

  _Cookie withFallbackDomain(String fallbackDomain) {
    if (domain.isNotEmpty) {
      return this;
    }
    return _Cookie(
      name: name,
      value: value,
      domain: fallbackDomain,
      path: path,
      expiresAt: expiresAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'value': value,
      'domain': domain,
      'path': path,
      'expiresAt': expiresAt,
    };
  }

  static _Cookie fromMap(Map<String, dynamic> map) {
    return _Cookie(
      name: map['name']?.toString() ?? '',
      value: map['value']?.toString() ?? '',
      domain: map['domain']?.toString() ?? '',
      path: map['path']?.toString() ?? '/',
      expiresAt: map['expiresAt'] is num
          ? (map['expiresAt'] as num).toInt()
          : null,
    );
  }

  static _Cookie? parseSetCookie(String raw, String fallbackUrl) {
    final uri = Uri.tryParse(fallbackUrl);
    if (uri == null || raw.isEmpty) {
      return null;
    }

    final segments = raw.split(';').map((e) => e.trim()).toList();
    if (segments.isEmpty || !segments.first.contains('=')) {
      return null;
    }

    final first = segments.first;
    final equalIndex = first.indexOf('=');
    if (equalIndex <= 0) {
      return null;
    }

    final name = first.substring(0, equalIndex).trim();
    final value = first.substring(equalIndex + 1).trim();

    String domain = uri.host;
    String path = '/';
    int? expiresAt;

    for (var i = 1; i < segments.length; i++) {
      final segment = segments[i];
      final index = segment.indexOf('=');
      if (index <= 0) {
        continue;
      }
      final key = segment.substring(0, index).trim().toLowerCase();
      final val = segment.substring(index + 1).trim();

      if (key == 'domain' && val.isNotEmpty) {
        domain = val.startsWith('.') ? val : '.$val';
      } else if (key == 'path' && val.isNotEmpty) {
        path = val;
      } else if (key == 'max-age') {
        final seconds = int.tryParse(val);
        if (seconds != null) {
          expiresAt = DateTime.now().millisecondsSinceEpoch + seconds * 1000;
        }
      } else if (key == 'expires') {
        final dt = DateTime.tryParse(val);
        if (dt != null) {
          expiresAt = dt.millisecondsSinceEpoch;
        }
      }
    }

    return _Cookie(
      name: name,
      value: value,
      domain: domain,
      path: path,
      expiresAt: expiresAt,
    );
  }
}
