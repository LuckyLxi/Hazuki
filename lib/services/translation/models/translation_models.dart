import 'dart:ui';

enum TranslationRegionKind { bubble, narration, sfx, other }

enum TranslationBoxSource { ai, detector }

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
  });

  final String id;
  final Rect box;
  final TranslationRegionKind kind;
  final String sourceText;
  final String translatedText;
  final bool sourceVertical;
  final Color? backgroundColor;
  final TranslationBoxSource boxSource;

  Map<String, dynamic> toJson() => {
    'id': id,
    'box': [box.left, box.top, box.right, box.bottom],
    'kind': kind.name,
    'src': sourceText,
    'dst': translatedText,
    'vertical': sourceVertical,
    'backgroundColor': backgroundColor?.toARGB32(),
    'boxSource': boxSource.name,
  };

  factory TranslationRegion.fromJson(Map<String, dynamic> json) {
    final box = (json['box'] as List).cast<num>();
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
