import 'dart:math' as math;

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

class ReaderTranslationOverlay extends StatelessWidget {
  const ReaderTranslationOverlay({
    super.key,
    required this.view,
    required this.bubbleStyle,
    required this.onToggleRegion,
  });
  final PageTranslationView view;
  final TranslationBubbleStyle bubbleStyle;
  final ValueChanged<String> onToggleRegion;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      final baseStyle =
          Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
      final scaler = MediaQuery.textScalerOf(context);
      return Stack(
        clipBehavior: Clip.none,
        children: [
          for (final region in view.result?.regions ?? <TranslationRegion>[])
            _region(context, region, size, baseStyle, scaler),
        ],
      );
    },
  );

  Widget _region(
    BuildContext context,
    TranslationRegion region,
    Size size,
    TextStyle baseStyle,
    TextScaler scaler,
  ) {
    var rect = Rect.fromLTRB(
      region.box.left * size.width,
      region.box.top * size.height,
      region.box.right * size.width,
      region.box.bottom * size.height,
    );
    final original = view.originalRegions.contains(region.id);
    final background = bubbleStyle == TranslationBubbleStyle.white
        ? Colors.white
        : region.backgroundColor ?? Colors.white;
    final style = baseStyle.copyWith(
      color: background.computeLuminance() > 0.5 ? Colors.black : Colors.white,
    );
    final maxFont = math.max(8.0, rect.height * 0.4);
    bool fits(double font, double width) {
      final painter = TextPainter(
        text: TextSpan(
          text: region.translatedText,
          style: style.copyWith(fontSize: font),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        textScaler: scaler,
      )..layout(maxWidth: math.max(1.0, width - 4));
      final fits =
          painter.height <= math.max(1.0, rect.height - 4) &&
          painter.width <= width - 4;
      painter.dispose();
      return fits;
    }

    if (!fits(8, rect.width)) {
      final expandedWidth = math.min(size.width, rect.width * 1.5);
      final left = (rect.center.dx - expandedWidth / 2).clamp(
        0.0,
        math.max(0.0, size.width - expandedWidth),
      );
      rect = Rect.fromLTWH(
        left.toDouble(),
        rect.top,
        expandedWidth,
        rect.height,
      );
    }
    var low = 8.0, high = maxFont;
    for (var iteration = 0; iteration < 12; iteration++) {
      final middle = (low + high) / 2;
      if (fits(middle, rect.width)) {
        low = middle;
      } else {
        high = middle;
      }
    }
    final fontStyle = style.copyWith(fontSize: low);
    final painter = TextPainter(
      text: TextSpan(text: '字', style: fontStyle),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
    final lines = math.max(1, ((rect.height - 4) / painter.height).floor());
    painter.dispose();
    return Positioned.fromRect(
      rect: rect,
      child: GestureDetector(
        key: ValueKey('translation-region-${region.id}'),
        behavior: HitTestBehavior.opaque,
        onLongPress: () => onToggleRegion(region.id),
        child: original
            ? const SizedBox.expand()
            : DecoratedBox(
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(
                    region.kind == TranslationRegionKind.bubble
                        ? math.min(rect.width, rect.height) * 0.25
                        : 3,
                  ),
                ),
                child: ClipRect(
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Center(
                      child: Text(
                        region.translatedText,
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.ltr,
                        style: fontStyle,
                        maxLines: lines,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
