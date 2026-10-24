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
        final box = _box(raw['box']);
        if (box == null) continue;
        var rect = box;
        final sourceBoxes = raw['boxes'] is List
            ? [for (final value in raw['boxes'] as List) ?_box(value)]
            : [box];
        for (final sourceBox in sourceBoxes) {
          rect = rect.expandToInclude(sourceBox);
        }
        final kind = _kind(raw['kind']);
        if (!translateSfx && _isSceneText(kind)) continue;
        regions.add(
          TranslationRegion(
            id: 'r$index',
            box: rect,
            kind: kind,
            sourceText: raw['src'] is String ? raw['src'] as String : '',
            translatedText: dst.trim(),
            sourceVertical:
                kind != TranslationRegionKind.caption &&
                raw['vertical'] == true,
            sourceBoxes: sourceBoxes,
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

  /// 解析本地检测模式；不相连的分组不挂载到其中某一个气泡。
  PageTranslationResult parseNumbered(
    String text, {
    required Map<String, Rect> boxes,
    required bool translateSfx,
    TranslationUsage usage = const TranslationUsage(),
  }) => parseNumberedWithPending(
    text,
    boxes: boxes,
    translateSfx: translateSfx,
    usage: usage,
  ).result;

  /// 未翻译且没有有效忽略原因的编号交给服务补译。
  ({PageTranslationResult result, Map<String, Rect> pending})
  parseNumberedWithPending(
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
      final members = <String>[];
      for (final id in ids) {
        if (id is! String || !boxes.containsKey(id)) continue;
        if (claimed.contains(id) || members.contains(id)) continue;
        members.add(id);
      }
      if (members.isEmpty) continue;
      final cluster = _connectedCluster([for (final id in members) boxes[id]!]);
      if (cluster.length != members.length) continue;
      Rect? union;
      for (final member in cluster) {
        claimed.add(members[member]);
        final box = boxes[members[member]]!;
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
          sourceVertical:
              kind != TranslationRegionKind.caption && raw['vertical'] == true,
          boxSource: TranslationBoxSource.detector,
          sourceBoxes: [for (final id in members) boxes[id]!],
          sourceIds: members,
        ),
      );
    }
    List<TranslationTerm> terms;
    try {
      terms = _terms(json);
    } catch (_) {
      terms = const [];
    }
    final ignored = json['ignored'];
    if (ignored is List) {
      for (final item in ignored) {
        if (item is! Map || item['ids'] is! List) continue;
        final reason = item['reason'];
        if (reason != 'non_text' &&
            reason != 'already_target' &&
            !(reason == 'excluded_kind' && !translateSfx)) {
          continue;
        }
        claimed.addAll(
          (item['ids'] as List).whereType<String>().where(boxes.containsKey),
        );
      }
    }
    return (
      result: PageTranslationResult(
        regions: regions,
        terms: terms,
        usage: usage,
      ),
      pending: {
        for (final entry in boxes.entries)
          if (!claimed.contains(entry.key)) entry.key: entry.value,
      },
    );
  }

  /// 相邻框之间允许的最大间隙（相对切片尺寸）。
  static const _maxClusterGap = 0.04;

  /// 返回第一簇的下标，调用方检查整组是否相连。
  ///
  /// 模型偶尔把相距很远或相互挨着的不同气泡编成一组，直接取并集会遮住大片画面。
  /// 同一气泡内的行距通常小于行高，不同气泡的文字之间至少隔着两侧留白。
  static List<int> _connectedCluster(List<Rect> boxes) {
    final parent = List<int>.generate(boxes.length, (index) => index);
    int find(int index) {
      while (parent[index] != index) {
        index = parent[index] = parent[parent[index]];
      }
      return index;
    }

    for (var a = 0; a < boxes.length; a++) {
      for (var b = a + 1; b < boxes.length; b++) {
        if (_adjacent(boxes[a], boxes[b])) parent[find(a)] = find(b);
      }
    }
    final clusters = <int, List<int>>{};
    for (var index = 0; index < boxes.length; index++) {
      clusters.putIfAbsent(find(index), () => []).add(index);
    }
    return clusters.values.first;
  }

  static Rect? _box(Object? raw) {
    if (raw is! List ||
        raw.length != 4 ||
        raw.any((value) => value is! num || !value.isFinite)) {
      return null;
    }
    final values = raw
        .cast<num>()
        .map((value) => value.clamp(0, 1000) / 1000)
        .toList();
    final rect = Rect.fromLTRB(
      math.min(values[0], values[2]),
      math.min(values[1], values[3]),
      math.max(values[0], values[2]),
      math.max(values[1], values[3]),
    );
    return rect.isEmpty ? null : rect;
  }

  static bool _adjacent(Rect a, Rect b) {
    final limit = math.min(
      _maxClusterGap,
      math.min(a.shortestSide, b.shortestSide) * 0.8,
    );
    final gapX = math.max(a.left, b.left) - math.min(a.right, b.right);
    final gapY = math.max(a.top, b.top) - math.min(a.bottom, b.bottom);
    return gapX <= limit && gapY <= limit;
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
