import 'package:flutter/foundation.dart';

import '../../../models/hazuki_models.dart';
import '../content/source_content_operations.dart';
import '../debug/source_debug_operations.dart';
import '../gateways/source_image_gateways.dart';
import '../image/source_image_operations.dart';
import '../models/source_contract_models.dart';
import '../runtime/source_runtime_operations.dart';
import '../runtime/source_runtime_view.dart';
import 'hazuki_source_adapter_base.dart';

class HazukiSourceImageAdapter implements SourceImageGateway {
  const HazukiSourceImageAdapter({
    required SourceRuntimeView runtime,
    required SourceImageOperations image,
  }) : _image = image,
       _runtime = runtime;

  final SourceImageOperations _image;
  final SourceRuntimeView _runtime;

  @override
  String get activeSourceKey => _runtime.activeSourceKey;
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
  }) => _image.downloadImageBytes(
    url,
    comicId: comicId,
    epId: epId,
    keepInMemory: keepInMemory,
    useDiskCache: useDiskCache,
    priority: priority,
    sourceKey: sourceKey,
  );
}

class HazukiSourceRecommendationAdapter implements SourceRecommendationGateway {
  HazukiSourceRecommendationAdapter({
    required SourceRuntimeView runtime,
    required SourceImageOperations image,
    required SourceRuntimeOperations runtimeOperations,
    required SourceDebugOperations debug,
  }) : _runtime = runtime,
       _image = image,
       _runtimeOperations = runtimeOperations,
       _debug = debug;

  final SourceRuntimeOperations _runtimeOperations;
  final SourceDebugOperations _debug;
  final SourceRuntimeView _runtime;
  final SourceImageOperations _image;

  @override
  String get activeSourceKey => _runtime.activeSourceKey;
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
  }) => _image.downloadImageBytes(
    url,
    comicId: comicId,
    epId: epId,
    keepInMemory: keepInMemory,
    useDiskCache: useDiskCache,
    priority: priority,
    sourceKey: sourceKey,
  );

  @override
  bool get softwareLogCaptureEnabled => _debug.softwareLogCaptureEnabled;
  @override
  Future<bool> loadSoftwareLogCaptureEnabled() =>
      _runtimeOperations.loadSoftwareLogCaptureEnabled();
  @override
  Future<void> setSoftwareLogCaptureEnabled(bool enabled) =>
      _runtimeOperations.setSoftwareLogCaptureEnabled(enabled);
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
  void clearCapturedLogs() => _debug.clearCapturedLogs();
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
  String get activeSourceKey => runtime.activeSourceKey;
  @override
  bool get isActiveJmSource => runtime.isActiveJmSource;
  @override
  bool get isInitialized => runtime.isInitialized;
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
    String order = 'mr',
    String sourceKey = '',
  }) => _content.searchComics(
    keyword: keyword,
    page: page,
    order: order,
    sourceKey: sourceKey,
  );
  @override
  Future<ComicDetailsData> loadComicDetails(
    String comicId, {
    String sourceKey = '',
  }) => _content.loadComicDetails(comicId, sourceKey: sourceKey);
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
  }) => _image.downloadImageBytes(
    url,
    comicId: comicId,
    epId: epId,
    keepInMemory: keepInMemory,
    useDiskCache: useDiskCache,
    priority: priority,
    sourceKey: sourceKey,
  );
}
