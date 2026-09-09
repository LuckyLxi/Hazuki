import 'dart:convert';
import 'package:flutter/services.dart';
import 'discover_recommendation_config.dart';

class AssetDiscoverRecommendationAuthors {
  AssetDiscoverRecommendationAuthors({
    this.assetPath = DiscoverDailyRecommendationConfig.authorsAssetPath,
    AssetBundle? bundle,
  }) : _bundle = bundle ?? rootBundle;

  final String assetPath;
  final AssetBundle _bundle;

  Future<List<String>> load() async {
    final raw = await _bundle.loadString(assetPath);
    final lines = const LineSplitter().convert(raw);
    final authors = <String>[];
    for (final line in lines) {
      final normalized = line
          .replaceFirst(RegExp(r'^\s*\d+\s*(?:[.\s]|\u3001)*'), '')
          .trim();
      if (normalized.isEmpty) {
        continue;
      }
      authors.add(normalized);
    }
    return authors;
  }
}
