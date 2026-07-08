import 'package:flutter/foundation.dart';

import '../../../models/hazuki_models.dart';
import '../../hazuki_source_service.dart';
import '../gateways/source_image_gateways.dart';
import 'hazuki_source_adapter_base.dart';

class HazukiSourceImageAdapter extends HazukiSourceAdapterBase
    implements SourceImageGateway {
  const HazukiSourceImageAdapter(super.source);

  @override
  String get activeSourceKey => source.activeSourceKey;
  @override
  Uint8List? peekImageBytesFromMemory(String url, {String sourceKey = ''}) =>
      source.peekImageBytesFromMemory(url, sourceKey: sourceKey);
  @override
  Future<Uint8List> downloadImageBytes(
    String url, {
    String comicId = '',
    String epId = '',
    bool keepInMemory = false,
    bool useDiskCache = true,
    bool priority = false,
    String sourceKey = '',
  }) => source.downloadImageBytes(
    url,
    comicId: comicId,
    epId: epId,
    keepInMemory: keepInMemory,
    useDiskCache: useDiskCache,
    priority: priority,
    sourceKey: sourceKey,
  );
}

class HazukiSourceRecommendationAdapter extends HazukiSourceImageAdapter
    implements SourceRecommendationGateway {
  const HazukiSourceRecommendationAdapter(super.source);

  @override
  bool get softwareLogCaptureEnabled => source.softwareLogCaptureEnabled;
  @override
  void addApplicationLog({
    required String level,
    required String title,
    Object? content,
    String source = 'app',
  }) => this.source.addApplicationLog(
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
  }) => this.source.addReaderLog(
    level: level,
    title: title,
    content: content,
    source: source,
  );
  @override
  Future<Map<String, dynamic>> collectTypedDebugInfo(String type) =>
      source.collectTypedDebugInfo(type);
  @override
  void clearCapturedLogs() => source.facade.clearCapturedLogs();
}

class HazukiSourceDailyRecommendationAdapter
    extends HazukiSourceListenableAdapter
    implements SourceDailyRecommendationGateway {
  const HazukiSourceDailyRecommendationAdapter(super.source);

  @override
  String get activeSourceKey => source.activeSourceKey;
  @override
  bool get isActiveJmSource => source.isActiveJmSource;
  @override
  bool get isInitialized => source.isInitialized;
  @override
  SourceRuntimeState get sourceRuntimeState => source.sourceRuntimeState;
  @override
  List<SourceCatalogEntry> get allowedSources =>
      source.runtimeRegistry.allowedSources;
  @override
  void logRuntimeRetryRequested(String value) =>
      source.logRuntimeRetryRequested(value);
  @override
  Future<SearchComicsResult> searchComics({
    required String keyword,
    required int page,
    String order = 'mr',
    String sourceKey = '',
  }) => source.searchComics(
    keyword: keyword,
    page: page,
    order: order,
    sourceKey: sourceKey,
  );
  @override
  Future<ComicDetailsData> loadComicDetails(
    String comicId, {
    String sourceKey = '',
  }) => source.loadComicDetails(comicId, sourceKey: sourceKey);
  @override
  Uint8List? peekImageBytesFromMemory(String url, {String sourceKey = ''}) =>
      source.peekImageBytesFromMemory(url, sourceKey: sourceKey);
  @override
  Future<Uint8List> downloadImageBytes(
    String url, {
    String comicId = '',
    String epId = '',
    bool keepInMemory = false,
    bool useDiskCache = true,
    bool priority = false,
    String sourceKey = '',
  }) => source.downloadImageBytes(
    url,
    comicId: comicId,
    epId: epId,
    keepInMemory: keepInMemory,
    useDiskCache: useDiskCache,
    priority: priority,
    sourceKey: sourceKey,
  );
}
