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
      final json = _decode(text);
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
        final kind = _kind(raw['kind']);
        if (!translateSfx && _isSceneText(kind)) continue;
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
      return PageTranslationResult(
        regions: regions,
        terms: _terms(json),
        usage: usage,
      );
    } catch (_) {
      throw const TranslationFailure(TranslationFailureKind.badResponse);
    }
  }

  /// 解析本地检测模式的编号响应；区域坐标取所认领检测框的并集。
  ///
  /// 采用宽松校验：未知编号丢弃，重复编号只保留首次归属，未被认领的框忽略；
  /// 只有 JSON 本身无法解析时才视为响应错误。
  PageTranslationResult parseNumbered(
    String text, {
    required Map<String, Rect> boxes,
    required bool translateSfx,
    TranslationUsage usage = const TranslationUsage(),
  }) {
    final Map<String, dynamic> json;
    final List rawRegions;
    try {
      json = _decode(text);
      rawRegions = json['regions'] as List;
    } catch (_) {
      throw const TranslationFailure(TranslationFailureKind.badResponse);
    }
    final claimed = <String>{};
    final regions = <TranslationRegion>[];
    for (var index = 0; index < rawRegions.length; index++) {
      final raw = rawRegions[index];
      if (raw is! Map<String, dynamic>) continue;
      final dst = raw['dst'];
      final ids = raw['ids'];
      if (dst is! String || dst.trim().isEmpty || ids is! List) continue;
      Rect? union;
      for (final id in ids) {
        if (id is! String) continue;
        final box = boxes[id];
        if (box == null || !claimed.add(id)) continue;
        union = union?.expandToInclude(box) ?? box;
      }
      if (union == null || union.isEmpty) continue;
      final kind = _kind(raw['kind']);
      if (!translateSfx && _isSceneText(kind)) continue;
      regions.add(
        TranslationRegion(
          id: 'r$index',
          box: union,
          kind: kind,
          sourceText: raw['src'] is String ? raw['src'] as String : '',
          translatedText: dst.trim(),
          sourceVertical: raw['vertical'] == true,
          boxSource: TranslationBoxSource.detector,
        ),
      );
    }
    List<TranslationTerm> terms;
    try {
      terms = _terms(json);
    } catch (_) {
      terms = const [];
    }
    return PageTranslationResult(regions: regions, terms: terms, usage: usage);
  }

  static Map<String, dynamic> _decode(String text) {
    var jsonText = text.trim();
    if (jsonText.startsWith('```')) {
      jsonText = jsonText.replaceFirst(
        RegExp(r'^```(?:json)?\s*', caseSensitive: false),
        '',
      );
      jsonText = jsonText.replaceFirst(RegExp(r'\s*```$'), '');
    }
    try {
      return jsonDecode(jsonText) as Map<String, dynamic>;
    } on FormatException {
      final start = jsonText.indexOf('{');
      final end = jsonText.lastIndexOf('}');
      if (start < 0 || end < start) rethrow;
      return jsonDecode(jsonText.substring(start, end + 1))
          as Map<String, dynamic>;
    }
  }

  static TranslationRegionKind _kind(Object? value) =>
      TranslationRegionKind.values.firstWhere(
        (kind) => kind.name == value,
        orElse: () => TranslationRegionKind.other,
      );

  static bool _isSceneText(TranslationRegionKind kind) =>
      kind == TranslationRegionKind.sfx || kind == TranslationRegionKind.other;

  static List<TranslationTerm> _terms(Map<String, dynamic> json) {
    final terms = <TranslationTerm>[];
    final rawTerms = json['terms'];
    if (rawTerms == null) return terms;
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
    return terms;
  }
}
