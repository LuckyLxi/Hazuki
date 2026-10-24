import '../plugins/source_search_capabilities.dart';
import 'package:flutter/foundation.dart';

import '../../../models/hazuki_models.dart';
import '../content/source_content_operations.dart';
import '../debug/source_debug_operations.dart';
import '../gateways/source_image_gateways.dart';
import '../gateways/source_runtime_gateways.dart';
import '../image/source_image_operations.dart';
import '../models/source_contract_models.dart';
import '../runtime/source_runtime_diagnostics_operations.dart';
import '../runtime/source_runtime_view.dart';
import '../models/source_task.dart';
import 'hazuki_source_adapter_base.dart';

/// 图片与诊断日志 Gateway 共用一个实现，推荐区同时依赖这两者。
class HazukiSourceImageAdapter
    implements
        SourceImageGateway,
        SourceDebugGateway,
        SourceRecommendationGateway {
  const HazukiSourceImageAdapter({
    required SourceRuntimeView runtime,
    required SourceImageOperations image,
    required SourceRuntimeDiagnosticsOperations diagnostics,
    required SourceDebugOperations debug,
  }) : _runtime = runtime,
       _image = image,
       _diagnostics = diagnostics,
       _debug = debug;

  final SourceRuntimeDiagnosticsOperations _diagnostics;
  final SourceDebugOperations _debug;
  final SourceRuntimeView _runtime;
  final SourceImageOperations _image;

  @override
  String? get activeSourceKey => _runtime.activeSourceKey;
  @override
  Uint8List? peekImageBytesFromMemory(String url, {String sourceKey = ''}) =>
      _image.peekImageBytesFromMemory(url, sourceKey: sourceKey);
  @override
  Future<Uint8List> downloadImageBytes(
    String url, {
    String comicId = '',
    String epId = '',
    bool keepInMemory = false,
    bool useDiskCache = true,
    bool priority = false,
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  }) => _image.downloadImageBytes(
    url,
    comicId: comicId,
    epId: epId,
    keepInMemory: keepInMemory,
    useDiskCache: useDiskCache,
    priority: priority,
    sourceKey: sourceKey,
    taskOrigin: taskOrigin,
  );

  @override
  bool get softwareLogCaptureEnabled => _debug.softwareLogCaptureEnabled;
  @override
  Listenable get logChanges => _debug.logStore;
  @override
  Future<bool> loadSoftwareLogCaptureEnabled() =>
      _diagnostics.loadSoftwareLogCaptureEnabled();
  @override
  Future<void> setSoftwareLogCaptureEnabled(bool enabled) =>
      _diagnostics.setSoftwareLogCaptureEnabled(enabled);
  @override
  void addApplicationLog({
    required String level,
    required String title,
    Object? content,
    String source = 'app',
  }) => _debug.addApplicationLog(
    level: level,
    title: title,
    content: content,
    source: source,
  );
  @override
  void addReaderLog({
    required String level,
    required String title,
    Object? content,
    String source = 'reader',
  }) => _debug.addReaderLog(
    level: level,
    title: title,
    content: content,
    source: source,
  );
  @override
  Future<Map<String, dynamic>> collectTypedDebugInfo(String type) =>
      _debug.collectTypedDebugInfo(type);
  @override
  Future<Map<String, dynamic>> collectAllDebugInfo() =>
      _debug.collectAllDebugInfo();
  @override
  Future<void> clearCapturedLogs() => _debug.clearCapturedLogs();
}

class HazukiSourceDailyRecommendationAdapter
    extends HazukiSourceListenableAdapter
    implements SourceDailyRecommendationGateway {
  HazukiSourceDailyRecommendationAdapter({
    required SourceRuntimeView runtime,
    required SourceImageOperations image,
    required SourceContentOperations content,
  }) : _content = content,
       _image = image,
       super(runtime);

  final SourceContentOperations _content;
  final SourceImageOperations _image;

  @override
  String? get activeSourceKey => runtime.activeSourceKey;
  @override
  bool get supportsDirectComicId => runtime.supportsDirectComicId;
  @override
  DirectComicIdRules? directComicIdRulesForSource(String sourceKey) =>
      runtime.directComicIdRulesForSource(sourceKey);
  @override
  bool get isInitialized => runtime.isInitialized;
  @override
  bool get supportsDailyRecommendation => runtime.supportsDailyRecommendation;
  @override
  String? get sourceRevision => runtime.sourceRevision;
  @override
  DailyRecommendationConfig? dailyRecommendationForSource(String sourceKey) =>
      runtime.dailyRecommendationForSource(sourceKey);
  @override
  Future<List<SourceDailyRecommendationItem>> loadDailyRecommendations({
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  }) => _content.loadDailyRecommendations(
    sourceKey: sourceKey,
    taskOrigin: taskOrigin,
  );
  @override
  SourceRuntimeState get sourceRuntimeState => runtime.sourceRuntimeState;
  @override
  List<SourceCatalogEntry> get allowedSources =>
      runtime.runtimeRegistry.allowedSources;
  @override
  void logRuntimeRetryRequested(String value) =>
      runtime.logRuntimeRetryRequested(value);
  @override
  Future<SearchComicsResult> searchComics({
    required String keyword,
    required int page,
    String order = '',
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  }) => _content.searchComics(
    keyword: keyword,
    page: page,
    order: order,
    sourceKey: sourceKey,
    taskOrigin: taskOrigin,
  );
  @override
  Future<ComicDetailsData> loadComicDetails(
    String comicId, {
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  }) => _content.loadComicDetails(
    comicId,
    sourceKey: sourceKey,
    taskOrigin: taskOrigin,
  );
  @override
  Uint8List? peekImageBytesFromMemory(String url, {String sourceKey = ''}) =>
      _image.peekImageBytesFromMemory(url, sourceKey: sourceKey);
  @override
  Future<Uint8List> downloadImageBytes(
    String url, {
    String comicId = '',
    String epId = '',
    bool keepInMemory = false,
    bool useDiskCache = true,
    bool priority = false,
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  }) => _image.downloadImageBytes(
    url,
    comicId: comicId,
    epId: epId,
    keepInMemory: keepInMemory,
    useDiskCache: useDiskCache,
    priority: priority,
    sourceKey: sourceKey,
    taskOrigin: taskOrigin,
  );
}
