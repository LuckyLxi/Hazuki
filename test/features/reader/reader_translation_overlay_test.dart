import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/reader/support/reader_translation_controller.dart';
import 'package:hazuki/features/reader/view/reader_translation_overlay.dart';
import 'package:hazuki/features/reader/view/reader_translation_actions_sheet.dart';
import 'package:hazuki/features/reader/view/reader_overlay_builders.dart';
import 'package:hazuki/features/reader/state/reader_runtime_state.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/translation/manga_translation_settings_store.dart';
import 'package:hazuki/services/translation/models/translation_models.dart';
import 'package:mocktail/mocktail.dart';

class _Controller extends Mock implements ReaderTranslationController {}

void main() {
  for (final kind in [
    TranslationRegionKind.caption,
    TranslationRegionKind.narration,
  ]) {
    testWidgets(
      'fits full Japanese caption glyphs horizontally with kind=$kind',
      (tester) async {
        await tester.runAsync(() async {
          final font = FontLoader('RegressionJapanese')
            ..addFont(rootBundle.load('assets/fonts/NotoSansSC-VF.otf'));
          await font.load();
        });
        const translated = '「玲紗の好きな漫画、私も読んでみたいな」';
        final region = TranslationRegion(
          id: 'caption',
          box: const Rect.fromLTWH(.4, .5, .1, .025),
          layoutBox: const Rect.fromLTWH(.1, .5, .8, .025),
          kind: kind,
          sourceText: '玲紗喜歡的漫畫，真想讀讀看啊',
          translatedText: translated,
          sourceVertical: true,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(fontFamily: 'RegressionJapanese'),
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Center(
                child: SizedBox(
                  width: 400,
                  height: 400,
                  child: ReaderTranslationOverlay(
                    view: PageTranslationView(
                      status: PageTranslationStatus.done,
                      result: PageTranslationResult(
                        regions: [region],
                        terms: [],
                      ),
                    ),
                    bubbleStyle: TranslationBubbleStyle.sampled,
                    verticalText: true,
                    onToggleRegion: (_) {},
                  ),
                ),
              ),
            ),
          ),
        );
        final frame = find.byKey(const ValueKey('translation-region-caption'));
        final fitted = tester.renderObject<RenderFittedBox>(
          find.descendant(of: frame, matching: find.byType(FittedBox)),
        );
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: frame, matching: find.byType(RichText)),
        );
        expect(paragraph.text.toPlainText(), translated);
        expect(paragraph.didExceedMaxLines, isFalse);
        final painted = MatrixUtils.transformRect(
          paragraph.getTransformTo(fitted),
          Offset.zero & paragraph.size,
        );
        expect(painted.left, greaterThanOrEqualTo(-.01));
        expect(painted.top, greaterThanOrEqualTo(-.01));
        expect(painted.right, lessThanOrEqualTo(fitted.size.width + .01));
        expect(painted.bottom, lessThanOrEqualTo(fitted.size.height + .01));
        expect(
          find.descendant(of: frame, matching: find.byType(CustomPaint)),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  final result = PageTranslationResult(
    regions: const [
      TranslationRegion(
        id: 'r0',
        box: Rect.fromLTRB(0.25, 0.25, 0.75, 0.75),
        kind: TranslationRegionKind.bubble,
        sourceText: 'Hello',
        translatedText: '你好',
        sourceVertical: false,
      ),
    ],
    terms: [],
  );
  Widget app(Widget child) => MaterialApp(
    theme: ThemeData(fontFamily: 'NotoSansSC'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets(
    'maps letterboxed image coordinates and inherits the theme font',
    (tester) async {
      final controller = _Controller();
      final settings = MangaTranslationSettingsStore();
      final state = ValueNotifier(
        PageTranslationView(status: PageTranslationStatus.done, result: result),
      );
      addTearDown(settings.dispose);
      addTearDown(state.dispose);
      when(() => controller.modeOn).thenReturn(true);
      when(() => controller.settings).thenReturn(settings);
      when(() => controller.pageState('page')).thenReturn(state);
      await tester.pumpWidget(
        app(
          SizedBox(
            width: 400,
            height: 300,
            child: ReaderTranslatedImage(
              controller: controller,
              url: 'page',
              aspectRatio: () => 2,
              contain: true,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
      final imageBounds = tester.getRect(find.byType(ReaderTranslatedImage));
      final region = tester.getRect(
        find.byKey(const ValueKey('translation-region-r0')),
      );
      expect(
        region,
        Rect.fromLTWH(imageBounds.left + 100, imageBounds.top + 100, 200, 100),
      );
      expect(
        tester.widget<Text>(find.text('你好')).style!.fontFamily,
        'NotoSansSC',
      );
      expect(
        readerTranslationImageRect(const Size(400, 300), 2),
        const Rect.fromLTWH(0, 50, 400, 200),
      );
    },
  );

  testWidgets(
    'list mode fills its aspect ratio and off mode builds no overlay',
    (tester) async {
      final controller = _Controller();
      final settings = MangaTranslationSettingsStore();
      final state = ValueNotifier(
        PageTranslationView(status: PageTranslationStatus.done, result: result),
      );
      addTearDown(settings.dispose);
      addTearDown(state.dispose);
      when(() => controller.modeOn).thenReturn(true);
      when(() => controller.settings).thenReturn(settings);
      when(() => controller.pageState('page')).thenReturn(state);
      Widget content() => SizedBox(
        width: 200,
        height: 400,
        child: ReaderTranslatedImage(
          controller: controller,
          url: 'page',
          aspectRatio: () => 0.5,
          contain: false,
          child: const SizedBox.expand(),
        ),
      );
      await tester.pumpWidget(app(content()));
      final imageBounds = tester.getRect(find.byType(ReaderTranslatedImage));
      expect(
        tester.getRect(find.byKey(const ValueKey('translation-region-r0'))),
        Rect.fromLTWH(imageBounds.left + 50, imageBounds.top + 100, 100, 200),
      );
      when(() => controller.modeOn).thenReturn(false);
      await tester.pumpWidget(app(content()));
      expect(find.byType(ReaderTranslationOverlay), findsNothing);
      state.value = PageTranslationView(
        status: PageTranslationStatus.translating,
      );
      when(() => controller.modeOn).thenReturn(true);
      await tester.pumpWidget(app(content()));
      expect(find.byType(ReaderTranslationOverlay), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    },
  );

  testWidgets(
    'long press inside toggles only and outside preserves image save',
    (tester) async {
      var saved = 0, toggled = 0;
      final original = ValueNotifier(false);
      addTearDown(original.dispose);
      await tester.pumpWidget(
        app(
          GestureDetector(
            onLongPress: () => saved++,
            child: SizedBox(
              width: 400,
              height: 400,
              child: ColoredBox(
                color: Colors.grey,
                child: ValueListenableBuilder<bool>(
                  valueListenable: original,
                  builder: (context, value, _) => ReaderTranslationOverlay(
                    view: PageTranslationView(
                      status: PageTranslationStatus.done,
                      result: result,
                      originalRegions: value ? {'r0'} : {},
                    ),
                    bubbleStyle: TranslationBubbleStyle.sampled,
                    onToggleRegion: (_) {
                      toggled++;
                      original.value = !value;
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final center = tester.getCenter(
        find.byKey(const ValueKey('translation-region-r0')),
      );
      await tester.longPressAt(center);
      await tester.pump();
      expect(toggled, 1);
      expect(saved, 0);
      expect(find.text('你好'), findsNothing);
      await tester.longPressAt(center);
      await tester.pump();
      expect(toggled, 2);
      expect(saved, 0);
      expect(find.text('你好'), findsOneWidget);
      final bounds = tester.getRect(find.byType(ReaderTranslationOverlay));
      await tester.longPressAt(bounds.topLeft + const Offset(20, 20));
      await tester.pump();
      expect(saved, 1);
      expect(toggled, 2);
    },
  );

  test('vertical glyphs drop spaces and use vertical punctuation', () {
    expect(verticalTranslationGlyphs('你好， 「世界」！…'), [
      '你',
      '好',
      '︐',
      '﹁',
      '世',
      '界',
      '﹂',
      '︕',
      '︙',
    ]);
  });

  testWidgets('vertical source regions paint vertically only when enabled', (
    tester,
  ) async {
    final vertical = PageTranslationView(
      status: PageTranslationStatus.done,
      result: PageTranslationResult(
        regions: const [
          TranslationRegion(
            id: 'r0',
            box: Rect.fromLTRB(0.4, 0.1, 0.5, 0.9),
            kind: TranslationRegionKind.bubble,
            sourceText: 'ただいま',
            translatedText: '我回来了',
            sourceVertical: true,
          ),
        ],
        terms: [],
      ),
    );
    Widget overlay(bool verticalText) => app(
      SizedBox(
        width: 300,
        height: 400,
        child: ReaderTranslationOverlay(
          view: vertical,
          bubbleStyle: TranslationBubbleStyle.white,
          verticalText: verticalText,
          onToggleRegion: (_) {},
        ),
      ),
    );
    final region = find.byKey(const ValueKey('translation-region-r0'));
    await tester.pumpWidget(overlay(true));
    expect(find.text('我回来了'), findsNothing);
    expect(
      find.descendant(of: region, matching: find.byType(CustomPaint)),
      findsWidgets,
    );
    await tester.pumpWidget(overlay(false));
    expect(find.text('我回来了'), findsOneWidget);
  });

  testWidgets(
    'horizontal text stays inside boxes without covering neighbours',
    (tester) async {
      TranslationRegion region(String id, Rect box) => TranslationRegion(
        id: id,
        box: box,
        kind: TranslationRegionKind.narration,
        sourceText: '最近怎麼樣？',
        translatedText: 'How have you been lately?',
        sourceVertical: false,
      );
      await tester.pumpWidget(
        app(
          SizedBox(
            width: 400,
            height: 400,
            child: ReaderTranslationOverlay(
              view: PageTranslationView(
                status: PageTranslationStatus.done,
                result: PageTranslationResult(
                  regions: [
                    region('flat', const Rect.fromLTRB(0.3, 0.5, 0.6, 0.55)),
                    region('thin', const Rect.fromLTRB(0.45, 0.05, 0.5, 0.3)),
                    // 紧贴右侧的邻框，限制 thin 的扩展。
                    region('side', const Rect.fromLTRB(0.56, 0.05, 0.9, 0.3)),
                  ],
                  terms: const [],
                ),
              ),
              bubbleStyle: TranslationBubbleStyle.white,
              onToggleRegion: (_) {},
            ),
          ),
        ),
      );
      final overlay = tester.getRect(find.byType(ReaderTranslationOverlay));
      final flat = tester.getRect(
        find.byKey(const ValueKey('translation-region-flat')),
      );
      final thin = tester.getRect(
        find.byKey(const ValueKey('translation-region-thin')),
      );
      final side = tester.getRect(
        find.byKey(const ValueKey('translation-region-side')),
      );
      expect(
        flat,
        Rect.fromLTWH(overlay.left + 120, overlay.top + 200, 120, 20),
      );
      expect(
        thin,
        Rect.fromLTWH(overlay.left + 180, overlay.top + 20, 20, 100),
      );
      expect(thin.overlaps(side), isFalse);
    },
  );

  for (final verticalText in [false, true]) {
    testWidgets(
      'long text stays bounded with a readable font, vertical=$verticalText',
      (tester) async {
        const boxes = {
          'banner': Rect.fromLTWH(0.1, 0.1, 0.7, 0.08),
          'bubble': Rect.fromLTWH(0.4, 0.3, 0.06, 0.25),
        };
        final regions = [
          for (final entry in boxes.entries)
            TranslationRegion(
              id: entry.key,
              box: entry.value,
              kind: entry.key == 'banner'
                  ? TranslationRegionKind.narration
                  : TranslationRegionKind.bubble,
              sourceText: '原文',
              translatedText: verticalText
                  ? '这是需要完整显示在原有区域内的一段较长译文。' * 3
                  : 'Reisa, do you really like manga and anime? ' * 3,
              sourceVertical: entry.key == 'bubble',
            ),
        ];
        await tester.pumpWidget(
          app(
            MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: SizedBox(
                width: 400,
                height: 400,
                child: ReaderTranslationOverlay(
                  view: PageTranslationView(
                    status: PageTranslationStatus.done,
                    result: PageTranslationResult(regions: regions, terms: []),
                  ),
                  bubbleStyle: TranslationBubbleStyle.white,
                  verticalText: verticalText,
                  onToggleRegion: (_) {},
                ),
              ),
            ),
          ),
        );
        final overlay = tester.getRect(find.byType(ReaderTranslationOverlay));
        for (final region in regions) {
          final frameFinder = find.byKey(
            ValueKey('translation-region-${region.id}'),
          );
          final frame = tester.getRect(frameFinder);
          expect(
            frame,
            Rect.fromLTWH(
              overlay.left + region.box.left * 400,
              overlay.top + region.box.top * 400,
              region.box.width * 400,
              region.box.height * 400,
            ),
          );
          if (verticalText && region.sourceVertical) continue;
          final text = tester.widget<Text>(
            find.descendant(of: frameFinder, matching: find.byType(Text)),
          );
          if (region.kind == TranslationRegionKind.narration) {
            final fittedFinder = find.descendant(
              of: frameFinder,
              matching: find.byType(FittedBox),
            );
            final fitted = tester.renderObject<RenderFittedBox>(fittedFinder);
            final paragraph = tester.renderObject<RenderParagraph>(
              find.descendant(of: frameFinder, matching: find.byType(RichText)),
            );
            final painted = MatrixUtils.transformRect(
              paragraph.getTransformTo(fitted),
              Offset.zero & paragraph.size,
            );
            expect(painted.width, lessThanOrEqualTo(fitted.size.width + 0.01));
            expect(
              painted.height,
              lessThanOrEqualTo(fitted.size.height + 0.01),
            );
            expect(paragraph.didExceedMaxLines, isFalse);
            expect(text.softWrap, isFalse);
            continue;
          }
          final painter = TextPainter(
            text: TextSpan(text: text.data, style: text.style),
            textDirection: TextDirection.ltr,
            textAlign: text.textAlign!,
            textScaler: const TextScaler.linear(2),
            maxLines: text.maxLines,
          )..layout(maxWidth: frame.width - 4);
          expect(painter.height, lessThanOrEqualTo(frame.height - 4));
          expect(text.style!.fontSize, greaterThanOrEqualTo(8));
          expect(text.overflow, TextOverflow.ellipsis);
          expect(painter.didExceedMaxLines, isTrue);
          painter.dispose();
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'lays out across the balloon and paints only the source repairs',
    (tester) async {
      const region = TranslationRegion(
        id: 'wide',
        box: Rect.fromLTWH(0.47, 0.3, 0.06, 0.4),
        layoutBox: Rect.fromLTWH(0.25, 0.25, 0.5, 0.5),
        textPatches: [
          TranslationTextPatch(
            Rect.fromLTWH(0.48, 0.32, 0.02, 0.05),
            Color(0xffa0ebf5),
          ),
        ],
        backgroundColor: Color(0xffa0ebf5),
        kind: TranslationRegionKind.bubble,
        sourceText: '原文',
        translatedText: 'The translation should use the whole balloon.',
        sourceVertical: true,
      );
      Widget overlay(Set<String> originals) => app(
        SizedBox(
          width: 400,
          height: 400,
          child: ReaderTranslationOverlay(
            view: PageTranslationView(
              status: PageTranslationStatus.done,
              result: PageTranslationResult(regions: [region], terms: []),
              originalRegions: originals,
            ),
            bubbleStyle: TranslationBubbleStyle.sampled,
            onToggleRegion: (_) {},
          ),
        ),
      );
      await tester.pumpWidget(overlay({}));
      final frame = find.byKey(const ValueKey('translation-region-wide'));
      expect(tester.getSize(frame), const Size(200, 200));
      final text = tester.widget<Text>(find.text(region.translatedText));
      expect(text.style!.fontSize, greaterThan(12));
      expect(text.style!.color, Colors.black);
      expect(text.maxLines, greaterThan(1));
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: frame, matching: find.byType(RichText)),
      );
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(paragraph.size.height, greaterThan(text.style!.fontSize! * 2));
      expect(
        find.descendant(of: frame, matching: find.byType(DecoratedBox)),
        findsNothing,
      );
      expect(
        find.descendant(of: frame, matching: find.byType(CustomPaint)),
        findsOneWidget,
      );
      await tester.pumpWidget(overlay({'wide'}));
      expect(find.text(region.translatedText), findsNothing);
      expect(
        find.descendant(of: frame, matching: find.byType(CustomPaint)),
        findsNothing,
      );
    },
  );

  testWidgets('bottom action is optional and forwards tap and long press', (
    tester,
  ) async {
    final runtime = ReaderRuntimeState()
      ..applyImages(['page'])
      ..setControlsVisible(true);
    addTearDown(runtime.dispose);
    var taps = 0, presses = 0;
    Widget controls(bool enabled) => Builder(
      builder: (context) => buildReaderBottomControls(
        context: context,
        runtimeState: runtime,
        readerTheme: Theme.of(context),
        chapterPanelLoading: false,
        maybeTriggerSliderHaptic: (_, {force = false}) {},
        updateState: (update) => update(),
        goToPage: (_) async {},
        onResetZoom: () {},
        onTranslation: enabled ? () => taps++ : null,
        onTranslationLongPress: enabled ? () => presses++ : null,
        translationSelected: enabled,
      ),
    );
    await tester.pumpWidget(app(controls(false)));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.translate_rounded), findsNothing);
    await tester.pumpWidget(app(controls(true)));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.translate_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.translate_rounded));
    await tester.longPress(find.byIcon(Icons.translate_rounded));
    expect(taps, 1);
    expect(presses, 1);
  });

  for (final action in ReaderTranslationAction.values) {
    testWidgets('translation menu returns ${action.name}', (tester) async {
      ReaderTranslationAction? selected;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                selected = await showModalBottomSheet<ReaderTranslationAction>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const ReaderTranslationActionsSheet(),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      const labels = [
        'Translate this page again',
        'Glossary for this comic',
        'Clear glossary for this comic',
      ];
      for (final label in labels) {
        expect(find.text(label), findsOneWidget);
      }
      await tester.tap(find.text(labels[action.index]));
      await tester.pumpAndSettle();
      expect(selected, action);
    });
  }
}
