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

import '../app/chapter_title_resolver.dart';
import '../models/hazuki_models.dart';

part 'source/account_session_capability.dart';
part 'source/account_session_retry_support.dart';
part 'source/category_capability.dart';
part 'source/category_ranking_capability.dart';
part 'source/category_view_more_capability.dart';
part 'source/check_in_capability.dart';
part 'source/comic_details_cache_support.dart';
part 'source/comic_details_capability.dart';
part 'source/comments_avatar_support.dart';
part 'source/comments_capability.dart';
part 'source/cookie_store_support.dart';
part 'source/debug_capability.dart';
part 'source/debug_favorites_capability.dart';
part 'source/debug_log_storage_capability.dart';
part 'source/debug_report_capability.dart';
part 'source/explore_capability.dart';
part 'source/favorites_capability.dart';
part 'source/favorites_collection_capability.dart';
part 'source/favorites_management_capability.dart';
part 'source/image_cache_capability.dart';
part 'source/image_cache_download_capability.dart';
part 'source/image_cache_maintenance_capability.dart';
part 'source/image_prepare_capability.dart';
part 'source/image_prepare_segment_support.dart';
part 'source/image_prepare_unscramble_support.dart';
part 'source/js_bridge_support.dart';
part 'source/line_settings.dart';
part 'source/source_bootstrap_support.dart';
part 'source/source_file_management_capability.dart';
part 'source/source_loader_capability.dart';
part 'source/source_store_support.dart';
part 'source/version_update_capability.dart';

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

enum DailyCheckInStatus { success, alreadyCheckedIn, skipped }

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

  final Dio _dio = Dio(
    BaseOptions(
      responseType: ResponseType.plain,
      validateStatus: (status) => true,
      connectTimeout: const Duration(seconds: 35),
      receiveTimeout: const Duration(seconds: 90),
      sendTimeout: const Duration(seconds: 35),
    ),
  );

  static const String _cacheMaxBytesKey = 'image_cache_max_bytes';
  static const String _cacheAutoCleanModeKey = 'image_cache_auto_clean_mode';
  static const String _cacheLastAutoCleanAtKey =
      'image_cache_last_auto_clean_at';
  static const String _customEditedJmSourceKey = 'custom_edited_jm_source';
  static const String _softwareLogCaptureEnabledKey =
      'advanced_software_log_capture_enabled';

  static const int _defaultCacheMaxBytes = 400 * 1024 * 1024;
  static const String _defaultAutoCleanMode = 'size_overflow';
  static const Duration _discoverCacheTtl = Duration(days: 1);
  static const double _cacheOverflowTrimTargetRatio = 0.1;

  FlutterQjs? _engine;
  SharedPreferences? _prefs;
  Future<void>? _initFuture;

  String _statusText = 'source_initializing';
  SourceMeta? _sourceMeta;
  Map<String, dynamic>? _favoritesDebugCache;
  bool _isWarmingUpFavoritesDebug = false;
  bool _isRefreshingSource = false;
  bool _softwareLogCaptureEnabled = false;
  final List<Map<String, dynamic>> _recentNetworkLogs = [];
  final List<Map<String, dynamic>> _recentApplicationLogs = [];
  final List<Map<String, dynamic>> _recentReaderLogs = [];
  int _networkLogDedupedCount = 0;
  Map<String, dynamic>? _lastLoginDebugInfoStorage;
  Map<String, dynamic>? _lastSourceVersionDebugInfoStorage;

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

  Map<String, dynamic>? get _lastLoginDebugInfo =>
      _softwareLogCaptureEnabled ? _lastLoginDebugInfoStorage : null;
  set _lastLoginDebugInfo(Map<String, dynamic>? value) {
    _lastLoginDebugInfoStorage = _softwareLogCaptureEnabled ? value : null;
  }

  Map<String, dynamic>? get _lastSourceVersionDebugInfo =>
      _softwareLogCaptureEnabled ? _lastSourceVersionDebugInfoStorage : null;
  set _lastSourceVersionDebugInfo(Map<String, dynamic>? value) {
    _lastSourceVersionDebugInfoStorage = _softwareLogCaptureEnabled
        ? value
        : null;
  }

  String get statusText => _statusText;
  SourceMeta? get sourceMeta => _sourceMeta;
  bool get isInitialized => _engine != null && _sourceMeta != null;
  bool get softwareLogCaptureEnabled => _softwareLogCaptureEnabled;

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
}
