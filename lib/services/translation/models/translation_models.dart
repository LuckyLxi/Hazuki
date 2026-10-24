import 'dart:ui';

enum TranslationRegionKind { bubble, narration, caption, sfx, other }

enum TranslationBoxSource { ai, detector }

/// 原文笔画的局部底色修补；颜色可逐行变化以保留气泡渐变。
class TranslationTextPatch {
  const TranslationTextPatch(this.box, this.color);

  final Rect box;
  final Color color;
}

class TranslationRegion {
  const TranslationRegion({
    required this.id,
    required this.box,
    required this.kind,
    required this.sourceText,
    required this.translatedText,
    required this.sourceVertical,
    this.backgroundColor,
    this.boxSource = TranslationBoxSource.ai,
    this.layoutBox,
    this.textPatches,
    this.sourceBoxes = const [],
    this.sourceIds = const [],
  });

  final String id;
  final Rect box;
  final TranslationRegionKind kind;
  final String sourceText;
  final String translatedText;
  final bool sourceVertical;
  final Color? backgroundColor;
  final TranslationBoxSource boxSource;

  /// 本段原文的各行/列及检测编号，不能用排版框替代。
  final List<Rect> sourceBoxes;
  final List<String> sourceIds;

  /// 气泡内部的安全排版范围；[box] 始终保留原文位置。
  final Rect? layoutBox;

  /// 需要修补的原文笔画，按行合并为整页归一化矩形。null 表示未识别出底色区域。
  final List<TranslationTextPatch>? textPatches;

  Map<String, dynamic> toJson() => {
    'id': id,
    'box': [box.left, box.top, box.right, box.bottom],
    'kind': kind.name,
    'src': sourceText,
    'dst': translatedText,
    'vertical': sourceVertical,
    'backgroundColor': backgroundColor?.toARGB32(),
    'boxSource': boxSource.name,
    if (sourceBoxes.isNotEmpty)
      'sourceBoxes': [
        for (final area in sourceBoxes)
          [area.left, area.top, area.right, area.bottom],
      ],
    if (sourceIds.isNotEmpty) 'sourceIds': sourceIds,
    if (layoutBox case final area?)
      'layoutBox': [area.left, area.top, area.right, area.bottom],
    if (textPatches case final patches?)
      'textPatches': [
        for (final patch in patches)
          [
            patch.box.left,
            patch.box.top,
            patch.box.right,
            patch.box.bottom,
            patch.color.toARGB32(),
          ],
      ],
  };

  factory TranslationRegion.fromJson(Map<String, dynamic> json) {
    final box = (json['box'] as List).cast<num>();
    Rect rectFromJson(Object? value) {
      final values = (value as List).cast<num>();
      return Rect.fromLTRB(
        values[0].toDouble(),
        values[1].toDouble(),
        values[2].toDouble(),
        values[3].toDouble(),
      );
    }

    return TranslationRegion(
      id: json['id'] as String,
      box: Rect.fromLTRB(
        box[0].toDouble(),
        box[1].toDouble(),
        box[2].toDouble(),
        box[3].toDouble(),
      ),
      kind: TranslationRegionKind.values.byName(json['kind'] as String),
      sourceText: json['src'] as String,
      translatedText: json['dst'] as String,
      sourceVertical: json['vertical'] as bool,
      backgroundColor: json['backgroundColor'] == null
          ? null
          : Color(json['backgroundColor'] as int),
      boxSource: TranslationBoxSource.values.byName(
        json['boxSource'] as String,
      ),
      sourceBoxes:
          (json['sourceBoxes'] as List?)?.map(rectFromJson).toList() ??
          const [],
      sourceIds: (json['sourceIds'] as List?)?.cast<String>() ?? const [],
      layoutBox: json['layoutBox'] == null
          ? null
          : rectFromJson(json['layoutBox']),
      textPatches: (json['textPatches'] as List?)?.map((raw) {
        final values = raw as List;
        return TranslationTextPatch(
          rectFromJson(values),
          Color(values[4] as int),
        );
      }).toList(),
    );
  }
}

class TranslationTerm {
  const TranslationTerm({required this.source, required this.target});

  final String source;
  final String target;

  Map<String, dynamic> toJson() => {'src': source, 'dst': target};

  factory TranslationTerm.fromJson(Map<String, dynamic> json) =>
      TranslationTerm(
        source: json['src'] as String,
        target: json['dst'] as String,
      );
}

class TranslationUsage {
  const TranslationUsage({this.inputTokens = 0, this.outputTokens = 0});

  final int inputTokens;
  final int outputTokens;

  Map<String, dynamic> toJson() => {
    'inputTokens': inputTokens,
    'outputTokens': outputTokens,
  };

  factory TranslationUsage.fromJson(Map<String, dynamic> json) =>
      TranslationUsage(
        inputTokens: json['inputTokens'] as int,
        outputTokens: json['outputTokens'] as int,
      );
}

class PageTranslationResult {
  PageTranslationResult({
    required List<TranslationRegion> regions,
    required List<TranslationTerm> terms,
    this.usage = const TranslationUsage(),
  }) : regions = List.unmodifiable(regions),
       terms = List.unmodifiable(terms);

  final List<TranslationRegion> regions;
  final List<TranslationTerm> terms;
  final TranslationUsage usage;

  Map<String, dynamic> toJson() => {
    'regions': regions.map((region) => region.toJson()).toList(),
    'terms': terms.map((term) => term.toJson()).toList(),
    'usage': usage.toJson(),
  };

  factory PageTranslationResult.fromJson(Map<String, dynamic> json) =>
      PageTranslationResult(
        regions: (json['regions'] as List)
            .map(
              (value) =>
                  TranslationRegion.fromJson(value as Map<String, dynamic>),
            )
            .toList(),
        terms: (json['terms'] as List)
            .map(
              (value) =>
                  TranslationTerm.fromJson(value as Map<String, dynamic>),
            )
            .toList(),
        usage: TranslationUsage.fromJson(json['usage'] as Map<String, dynamic>),
      );
}
