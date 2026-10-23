import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'models/translation_models.dart';
import 'translation_failure.dart';

class TranslationResponseParser {
  const TranslationResponseParser();

  PageTranslationResult parse(
    String text, {
    required bool translateSfx,
    TranslationUsage usage = const TranslationUsage(),
  }) {
    try {
      var jsonText = text.trim();
      if (jsonText.startsWith('```')) {
        jsonText = jsonText.replaceFirst(
          RegExp(r'^```(?:json)?\s*', caseSensitive: false),
          '',
        );
        jsonText = jsonText.replaceFirst(RegExp(r'\s*```$'), '');
      }
      Map<String, dynamic> json;
      try {
        json = jsonDecode(jsonText) as Map<String, dynamic>;
      } on FormatException {
        final start = jsonText.indexOf('{');
        final end = jsonText.lastIndexOf('}');
        if (start < 0 || end < start) rethrow;
        json =
            jsonDecode(jsonText.substring(start, end + 1))
                as Map<String, dynamic>;
      }
      final rawRegions = json['regions'] as List;
      final regions = <TranslationRegion>[];
      for (var index = 0; index < rawRegions.length; index++) {
        final raw = rawRegions[index];
        if (raw is! Map<String, dynamic>) continue;
        final dst = raw['dst'];
        if (dst is! String || dst.trim().isEmpty) continue;
        final rawBox = raw['box'];
        if (rawBox is! List ||
            rawBox.length != 4 ||
            rawBox.any((value) => value is! num || !value.isFinite)) {
          continue;
        }
        final box = rawBox
            .cast<num>()
            .map((value) => value.clamp(0, 1000) / 1000)
            .toList();
        final rect = Rect.fromLTRB(
          math.min(box[0], box[2]),
          math.min(box[1], box[3]),
          math.max(box[0], box[2]),
          math.max(box[1], box[3]),
        );
        if (rect.isEmpty) continue;
        final kind = TranslationRegionKind.values.firstWhere(
          (kind) => kind.name == raw['kind'],
          orElse: () => TranslationRegionKind.other,
        );
        if (!translateSfx &&
            (kind == TranslationRegionKind.sfx ||
                kind == TranslationRegionKind.other)) {
          continue;
        }
        regions.add(
          TranslationRegion(
            id: 'r$index',
            box: rect,
            kind: kind,
            sourceText: raw['src'] is String ? raw['src'] as String : '',
            translatedText: dst.trim(),
            sourceVertical: raw['vertical'] == true,
          ),
        );
      }
      final terms = <TranslationTerm>[];
      final rawTerms = json['terms'];
      if (rawTerms != null) {
        for (final raw in rawTerms as List) {
          if (raw is! Map<String, dynamic>) continue;
          final src = raw['src'];
          final dst = raw['dst'];
          if (src is String &&
              dst is String &&
              src.trim().isNotEmpty &&
              dst.trim().isNotEmpty) {
            terms.add(TranslationTerm(source: src.trim(), target: dst.trim()));
          }
        }
      }
      return PageTranslationResult(
        regions: regions,
        terms: terms,
        usage: usage,
      );
    } catch (_) {
      throw const TranslationFailure(TranslationFailureKind.badResponse);
    }
  }
}
