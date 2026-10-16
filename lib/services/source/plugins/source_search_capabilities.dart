import 'source_plugin_exception.dart';

/// Declarative ID matching shared by plugin inspection and search routing.
class DirectComicIdRules {
  DirectComicIdRules._(this.patterns, this.extractDigits);

  final List<RegExp> patterns;
  final bool extractDigits;

  static DirectComicIdRules? parse(Object? value) {
    if (value == null) return null;
    if (value is! Map ||
        value['patterns'] is! List ||
        value['extractDigits'] is! bool) {
      throw const SourcePluginException('plugin_invalid_manifest');
    }
    final patterns = <RegExp>[];
    for (final pattern in value['patterns'] as List) {
      if (pattern is! String || pattern.isEmpty) {
        throw const SourcePluginException('plugin_invalid_manifest');
      }
      try {
        final expression = RegExp('^(?:$pattern)\$', caseSensitive: false);
        // The empty alternative provides a match even if the rule rejects ''.
        final captures = RegExp('(?:$pattern)|').firstMatch('')!.groupCount;
        if (captures == 0) {
          throw const SourcePluginException('plugin_invalid_manifest');
        }
        patterns.add(expression);
      } on FormatException {
        throw const SourcePluginException('plugin_invalid_manifest');
      }
    }
    if (patterns.isEmpty) {
      throw const SourcePluginException('plugin_invalid_manifest');
    }
    return DirectComicIdRules._(
      List.unmodifiable(patterns),
      value['extractDigits'] as bool,
    );
  }

  String? match(String keyword) {
    final text = keyword.trim();
    if (text.isEmpty) return null;
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match == null || match.start != 0 || match.end != text.length) {
        continue;
      }
      final id = match.group(1)?.trim();
      if (id != null && id.isNotEmpty) return id;
    }
    return null;
  }

  String? extract(String text) {
    if (!extractDigits) return null;
    final trimmed = text.trim();
    final digits = trimmed.replaceAll(RegExp(r'[^\d]'), '');
    return digits.length >= 3 && digits != trimmed ? digits : null;
  }
}

enum DailyRecommendationMode { authors, plugin }

class DailyRecommendationConfig {
  const DailyRecommendationConfig({
    this.searchOrder = '',
    this.mode = DailyRecommendationMode.authors,
  });

  final String searchOrder;
  final DailyRecommendationMode mode;
  String get cacheKey => mode == DailyRecommendationMode.plugin
      ? 'plugin'
      : 'authors:$searchOrder';

  static DailyRecommendationConfig? parse(Object? value) {
    if (value == null) return null;
    if (value is! Map) {
      throw const SourcePluginException('plugin_invalid_manifest');
    }
    final mode = value['mode'] ?? 'authors';
    if (mode == 'plugin' && !value.containsKey('searchOrder')) {
      return const DailyRecommendationConfig(
        mode: DailyRecommendationMode.plugin,
      );
    }
    if (mode != 'authors' ||
        value['searchOrder'] is! String ||
        (value['searchOrder'] as String).trim().isEmpty) {
      throw const SourcePluginException('plugin_invalid_manifest');
    }
    return DailyRecommendationConfig(
      searchOrder: (value['searchOrder'] as String).trim(),
    );
  }
}
