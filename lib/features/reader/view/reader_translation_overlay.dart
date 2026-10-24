import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../services/translation/manga_translation_settings_store.dart';
import '../../../services/translation/models/translation_models.dart';
import '../../../shared/translation/translation_failure_message.dart';
import '../support/reader_translation_controller.dart';

Rect readerTranslationImageRect(Size viewport, double aspectRatio) {
  final source = Size(aspectRatio, 1);
  final fit = applyBoxFit(BoxFit.contain, source, viewport);
  return Alignment.center.inscribe(fit.destination, Offset.zero & viewport);
}

class ReaderTranslatedImage extends StatelessWidget {
  const ReaderTranslatedImage({
    super.key,
    required this.child,
    required this.controller,
    required this.url,
    required this.aspectRatio,
    required this.contain,
  });
  final Widget child;
  final ReaderTranslationController controller;
  final String url;
  final double? Function() aspectRatio;
  final bool contain;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      if (!controller.modeOn) return child;
      return ValueListenableBuilder<PageTranslationView>(
        valueListenable: controller.pageState(url),
        builder: (context, state, _) {
          if (state.status == PageTranslationStatus.idle) return child;
          return Stack(
            fit: StackFit.passthrough,
            children: [
              child,
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final ratio = aspectRatio();
                    final rect = contain && ratio != null
                        ? readerTranslationImageRect(constraints.biggest, ratio)
                        : Offset.zero & constraints.biggest;
                    return Stack(
                      children: [
                        Positioned.fromRect(
                          rect: rect,
                          child: Stack(
                            children: [
                              if (state.result != null &&
                                  (!contain || ratio != null))
                                Positioned.fill(
                                  child: ReaderTranslationOverlay(
                                    view: state,
                                    bubbleStyle:
                                        controller.settings.bubbleStyle,
                                    verticalText:
                                        controller.settings.verticalText &&
                                        _verticalLanguages.contains(
                                          controller.settings.targetLanguage,
                                        ),
                                    onToggleRegion: (id) =>
                                        controller.toggleRegion(url, id),
                                  ),
                                ),
                              if (state.status ==
                                      PageTranslationStatus.queued ||
                                  state.status ==
                                      PageTranslationStatus.translating)
                                const Positioned(
                                  right: 8,
                                  top: 8,
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              if (state.status == PageTranslationStatus.failed)
                                Positioned(
                                  right: 4,
                                  top: 4,
                                  child: IconButton(
                                    tooltip: state.failure == null
                                        ? l10n(context).commonRetry
                                        : translationFailureMessage(
                                            l10n(context),
                                            state.failure!.kind,
                                          ),
                                    onPressed: () => controller.retry(url),
                                    icon: const Icon(
                                      Icons.error_outline_rounded,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

/// 支持竖排显示的目标语言。
const _verticalLanguages = {
  TranslationTargetLanguage.simplifiedChinese,
  TranslationTargetLanguage.traditionalChinese,
  TranslationTargetLanguage.japanese,
};

class ReaderTranslationOverlay extends StatelessWidget {
  const ReaderTranslationOverlay({
    super.key,
    required this.view,
    required this.bubbleStyle,
    required this.onToggleRegion,
    this.verticalText = false,
  });
  final PageTranslationView view;
  final TranslationBubbleStyle bubbleStyle;
  final ValueChanged<String> onToggleRegion;

  /// 为 true 时，原文竖排的区域按竖排绘制译文。
  final bool verticalText;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      final baseStyle =
          Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
      final scaler = MediaQuery.textScalerOf(context);
      final regions = view.result?.regions ?? const <TranslationRegion>[];
      return Stack(
        clipBehavior: Clip.none,
        children: [
          for (final region in regions)
            _region(
              region,
              Rect.fromLTRB(
                (region.layoutBox ?? region.box).left * size.width,
                (region.layoutBox ?? region.box).top * size.height,
                (region.layoutBox ?? region.box).right * size.width,
                (region.layoutBox ?? region.box).bottom * size.height,
              ),
              size,
              baseStyle,
              scaler,
            ),
        ],
      );
    },
  );

  Widget _region(
    TranslationRegion region,
    Rect rect,
    Size imageSize,
    TextStyle baseStyle,
    TextScaler scaler,
  ) {
    final background = bubbleStyle == TranslationBubbleStyle.white
        ? Colors.white
        : region.backgroundColor ?? Colors.white;
    final style = baseStyle.copyWith(
      color: background.computeLuminance() > 0.179
          ? Colors.black
          : Colors.white,
    );
    final caption =
        region.kind == TranslationRegionKind.caption ||
        region.kind == TranslationRegionKind.narration &&
            rect.width > rect.height * 4;
    if (caption) {
      return _frame(
        region,
        rect,
        imageSize,
        background,
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            region.translatedText,
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
            style: style.copyWith(
              fontSize: math.max(8.0, imageSize.width * 0.042),
            ),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
          ),
        ),
      );
    }
    if (verticalText && region.sourceVertical) {
      return _verticalRegion(
        region,
        rect,
        imageSize,
        background,
        style,
        scaler,
      );
    }
    // 同一页采用相近的字号上限，避免短句被放得过大。
    final padding = region.layoutBox == null ? 4.0 : 0.0;
    final maxFont = math.max(
      8.0,
      math.min(imageSize.width * 0.042, rect.height - padding),
    );
    // 西文单词不允许在词中折行；中日韩文字可在任意字间换行，不参与该检查。
    final words = region.translatedText
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty && !_breakableScript.hasMatch(word))
        .toList();
    bool fits(double font, Rect area) {
      final fontStyle = style.copyWith(fontSize: font);
      final painter = TextPainter(
        text: TextSpan(text: region.translatedText, style: fontStyle),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        textScaler: scaler,
      )..layout(maxWidth: math.max(1.0, area.width - padding));
      var fits =
          painter.height <= math.max(1.0, area.height - padding) &&
          painter.width <= area.width - padding;
      painter.dispose();
      for (final word in words) {
        if (!fits) break;
        final measure = TextPainter(
          text: TextSpan(text: word, style: fontStyle),
          textDirection: TextDirection.ltr,
          textScaler: scaler,
        )..layout();
        fits = measure.width <= area.width - padding;
        measure.dispose();
      }
      return fits;
    }

    var low = 8.0, high = maxFont;
    for (var iteration = 0; iteration < 12; iteration++) {
      final middle = (low + high) / 2;
      if (fits(middle, rect)) {
        low = middle;
      } else {
        high = middle;
      }
    }
    final fontStyle = style.copyWith(fontSize: low);
    final measure = TextPainter(
      text: TextSpan(text: region.translatedText, style: fontStyle),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout(maxWidth: math.max(1, rect.width - padding));
    final maxLines = fits(low, rect)
        ? measure.computeLineMetrics().length
        : math.max(
            1,
            ((rect.height - padding) / measure.preferredLineHeight).floor(),
          );
    measure.dispose();
    return _frame(
      region,
      rect,
      imageSize,
      background,
      Center(
        child: Text(
          region.translatedText,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
          style: fontStyle,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _verticalRegion(
    TranslationRegion region,
    Rect rect,
    Size imageSize,
    Color background,
    TextStyle style,
    TextScaler scaler,
  ) {
    final glyphs = verticalTranslationGlyphs(region.translatedText);
    final padding = region.layoutBox == null ? 4.0 : 0.0;
    bool fits(double font, Rect area) => _VerticalTextLayout(
      glyphs,
      style.copyWith(fontSize: font, height: _verticalLineHeight),
      scaler,
    ).fits(Size(area.width - padding, area.height - padding));

    var low = 8.0,
        high = math.max(
          8.0,
          math.min(imageSize.width * 0.042, rect.width * 0.6),
        );
    for (var iteration = 0; iteration < 12; iteration++) {
      final middle = (low + high) / 2;
      if (fits(middle, rect)) {
        low = middle;
      } else {
        high = middle;
      }
    }
    return _frame(
      region,
      rect,
      imageSize,
      background,
      CustomPaint(
        size: Size.infinite,
        painter: _VerticalTextPainter(
          glyphs,
          style.copyWith(fontSize: low, height: _verticalLineHeight),
          scaler,
        ),
      ),
    );
  }

  Widget _frame(
    TranslationRegion region,
    Rect rect,
    Size imageSize,
    Color background,
    Widget child,
  ) {
    final original = view.originalRegions.contains(region.id);
    Rect scale(Rect area) => Rect.fromLTRB(
      area.left * imageSize.width,
      area.top * imageSize.height,
      area.right * imageSize.width,
      area.bottom * imageSize.height,
    );
    var bounds =
        region.kind == TranslationRegionKind.caption && region.layoutBox != null
        ? rect
        : rect.expandToInclude(scale(region.box));
    final patches = region.textPatches;
    for (final patch in patches ?? const <TranslationTextPatch>[]) {
      bounds = bounds.expandToInclude(scale(patch.box));
    }
    final origin = bounds.topLeft;
    final text = ClipRect(
      child: Padding(
        padding: EdgeInsets.all(
          region.layoutBox == null &&
                  region.kind != TranslationRegionKind.caption
              ? 2
              : 0,
        ),
        child: child,
      ),
    );
    return Positioned.fromRect(
      rect: bounds,
      child: GestureDetector(
        key: ValueKey('translation-region-${region.id}'),
        behavior: HitTestBehavior.opaque,
        onLongPress: () => onToggleRegion(region.id),
        child: original
            ? const SizedBox.expand()
            : Stack(
                children: [
                  if (patches != null)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _TranslationErasePainter([
                          for (final patch in patches)
                            TranslationTextPatch(
                              scale(patch.box).shift(-origin),
                              bubbleStyle == TranslationBubbleStyle.white
                                  ? Colors.white
                                  : patch.color,
                            ),
                        ]),
                      ),
                    ),
                  Positioned.fromRect(
                    rect: rect.shift(-origin),
                    child:
                        patches != null &&
                            bubbleStyle == TranslationBubbleStyle.sampled
                        ? text
                        : DecoratedBox(
                            decoration: BoxDecoration(
                              color: background,
                              borderRadius: BorderRadius.circular(
                                region.kind == TranslationRegionKind.bubble
                                    ? math.min(rect.width, rect.height) * 0.25
                                    : 3,
                              ),
                            ),
                            child: text,
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _TranslationErasePainter extends CustomPainter {
  _TranslationErasePainter(this.patches);

  final List<TranslationTextPatch> patches;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = false;
    for (final patch in patches) {
      paint.color = patch.color;
      canvas.drawRect(patch.box, paint);
    }
  }

  @override
  bool shouldRepaint(_TranslationErasePainter oldDelegate) =>
      !listEquals(patches, oldDelegate.patches);
}

/// 可在任意字间换行的文字（中日韩），不做整词检查。
final _breakableScript = RegExp(r'[぀-ヿ㐀-鿿豈-﫿가-힯]');

/// 竖排字距：比横排默认行高略紧，贴近漫画竖排的字距。
const _verticalLineHeight = 1.08;

/// 横排标点到竖排字形的替换表。
const _verticalForms = {
  '，': '︐',
  ',': '︐',
  '、': '︑',
  '。': '︒',
  '：': '︓',
  ':': '︓',
  '；': '︔',
  ';': '︔',
  '！': '︕',
  '!': '︕',
  '？': '︖',
  '?': '︖',
  '…': '︙',
  '‥': '︰',
  '—': '︱',
  '–': '︲',
  '（': '︵',
  '）': '︶',
  '(': '︵',
  ')': '︶',
  '「': '﹁',
  '」': '﹂',
  '『': '﹃',
  '』': '﹄',
  '【': '︻',
  '】': '︼',
  '〔': '︹',
  '〕': '︺',
  '《': '︽',
  '》': '︾',
  '〈': '︿',
  '〉': '﹀',
  '“': '﹁',
  '”': '﹂',
  '‘': '﹃',
  '’': '﹄',
};

/// 没有竖排字形、需要旋转 90° 绘制的字符，如长音符与波浪线。
const _rotatedGlyphs = {'ー', '～', '~', '〜', '-', '－', '=', '＝', '_'};

/// 把译文拆成竖排逐格绘制的字形；空白不占格，标点换成竖排字形。
@visibleForTesting
List<String> verticalTranslationGlyphs(String text) => [
  for (final rune in text.runes)
    if (String.fromCharCode(rune).trim().isNotEmpty)
      _verticalForms[String.fromCharCode(rune)] ?? String.fromCharCode(rune),
];

/// 竖排的格子布局：字从上往下、列从右往左，各列字数尽量均衡。
class _VerticalTextLayout {
  _VerticalTextLayout(this.glyphs, TextStyle style, TextScaler scaler) {
    final probe = TextPainter(
      text: TextSpan(text: '字', style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
    cellWidth = probe.width;
    cellHeight = probe.height;
    probe.dispose();
  }

  final List<String> glyphs;
  late final double cellWidth;
  late final double cellHeight;

  double get columnGap => cellWidth * 0.2;

  /// 返回每列字数与列数；可用高度放不下一个字时返回 null。
  (int, int)? grid(Size size) {
    final maxRows = (size.height / cellHeight).floor();
    if (maxRows <= 0 || glyphs.isEmpty) return null;
    final columns = (glyphs.length / maxRows).ceil();
    return ((glyphs.length / columns).ceil(), columns);
  }

  double widthOf(int columns) =>
      columns * cellWidth + math.max(0, columns - 1) * columnGap;

  bool fits(Size size) {
    final cells = grid(size);
    return cells != null && widthOf(cells.$2) <= size.width;
  }
}

class _VerticalTextPainter extends CustomPainter {
  _VerticalTextPainter(this.glyphs, this.style, this.scaler);

  final List<String> glyphs;
  final TextStyle style;
  final TextScaler scaler;

  @override
  void paint(Canvas canvas, Size size) {
    final layout = _VerticalTextLayout(glyphs, style, scaler);
    final cells = layout.grid(size);
    if (cells == null) return;
    var (rows, columns) = cells;
    var visible = glyphs;
    // 最小字号仍放不下时只画能放下的列，末格以省略号收尾。
    final maxColumns = math.max(
      1,
      ((size.width + layout.columnGap) / (layout.cellWidth + layout.columnGap))
          .floor(),
    );
    if (columns > maxColumns) {
      columns = maxColumns;
      rows = (size.height / layout.cellHeight).floor();
      visible = [...glyphs.take(rows * columns - 1), '︙'];
    }
    final blockWidth = layout.widthOf(columns);
    final usedRows = math.min(rows, visible.length);
    final right = (size.width + blockWidth) / 2;
    final top = (size.height - usedRows * layout.cellHeight) / 2;
    for (var index = 0; index < visible.length; index++) {
      final column = index ~/ rows, row = index % rows;
      final center = Offset(
        right -
            column * (layout.cellWidth + layout.columnGap) -
            layout.cellWidth / 2,
        top + row * layout.cellHeight + layout.cellHeight / 2,
      );
      final glyph = visible[index];
      final painter = TextPainter(
        text: TextSpan(text: glyph, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout();
      final offset = Offset(-painter.width / 2, -painter.height / 2);
      if (_rotatedGlyphs.contains(glyph)) {
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(math.pi / 2);
        painter.paint(canvas, offset);
        canvas.restore();
      } else {
        painter.paint(canvas, center + offset);
      }
      painter.dispose();
    }
  }

  @override
  bool shouldRepaint(_VerticalTextPainter oldDelegate) =>
      !listEquals(oldDelegate.glyphs, glyphs) ||
      oldDelegate.style != style ||
      oldDelegate.scaler != scaler;
}
