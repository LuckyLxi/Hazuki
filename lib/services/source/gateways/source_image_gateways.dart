import 'package:flutter/foundation.dart';

import 'source_content_gateways.dart';
import 'source_runtime_gateways.dart';

abstract interface class SourceImageGateway {
  String get activeSourceKey;

  Uint8List? peekImageBytesFromMemory(String url, {String sourceKey = ''});
  Future<Uint8List> downloadImageBytes(
    String url, {
    String comicId = '',
    String epId = '',
    bool keepInMemory = false,
    bool useDiskCache = true,
    String sourceKey = '',
  });
}

abstract interface class SourceRecommendationGateway
    implements SourceImageGateway, SourceDebugGateway {}

abstract interface class SourceDailyRecommendationGateway
    implements SourceSearchGateway, SourceImageGateway {
  bool get isInitialized;
}
