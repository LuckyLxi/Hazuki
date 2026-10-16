import '../plugins/source_search_capabilities.dart';
import 'package:flutter/foundation.dart';

import 'source_content_gateways.dart';
import 'source_runtime_gateways.dart';
import '../models/source_contract_models.dart';

abstract interface class SourceImageGateway {
  String? get activeSourceKey;

  Uint8List? peekImageBytesFromMemory(String url, {String sourceKey = ''});
  Future<Uint8List> downloadImageBytes(
    String url, {
    String comicId = '',
    String epId = '',
    bool keepInMemory = false,
    bool useDiskCache = true,
    bool priority = false,
    String sourceKey = '',
  });
}

abstract interface class SourceRecommendationGateway
    implements SourceImageGateway, SourceDebugGateway {}

abstract interface class SourceDailyRecommendationGateway
    implements SourceSearchGateway, SourceImageGateway {
  bool get isInitialized;
  bool get supportsDailyRecommendation;
  DailyRecommendationConfig? dailyRecommendationForSource(String sourceKey);
  Future<List<SourceDailyRecommendationItem>> loadDailyRecommendations({
    String sourceKey = '',
  });
}
