import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hazuki/app/service_locator.dart';
import 'package:hazuki/features/comic_detail/view/comic_detail_destination_route.dart';
import 'package:hazuki/features/reader/support/reader_dependencies.dart';
import 'package:hazuki/features/reader/support/reader_page_context.dart';
import 'package:hazuki/features/reader/view/reader_overlay_host.dart';
import 'package:hazuki/features/reader/view/reader_page.dart';
import 'package:hazuki/features/reader/view/reader_state_views.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/manga_download/manga_download_service.dart';
import 'package:hazuki/services/reading_progress_service.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/shared/reading/reader_settings_store.dart';
import 'package:hazuki/shared/ui_flags.dart';
import 'package:hazuki/shared/windows/window_title_bar_control.dart';
import 'package:hazuki/widgets/expanding_chapter_sheet.dart';
import 'package:hazuki/widgets/hazuki_frosted_menu_button.dart';

import '../../support/source_presentation_fixtures.dart';
import '../../support/test_service_locator.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      ReaderSettingsStore.windowsShortcutsGuideSeenKey: true,
    });
    await ensureTestServiceLocator();
    final previous = hazukiNoImageModeNotifier.value;
    hazukiNoImageModeNotifier.value = true;
    addTearDown(() => hazukiNoImageModeNotifier.value = previous);
  });

  testWidgets('exiting during chapter load ignores the late response', (
    tester,
  ) async {
    final source = _PendingReader();
    await _mountReader(
      tester,
      _reader(sourceReader: source, offlineMode: false),
    );
    expect(find.byType(ReaderLoadingStateView), findsOneWidget);
    final cancellation = source.origin!.cancellation!;
    expect(cancellation.reason, isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(cancellation.reason, SourceTaskStopReason.ownerDisposed);
    source.images.complete(['late-image']);
    await tester.pumpAndSettle();

    expect(source.logs, contains('Reader session closed'));
    expect(
      source.logs,
      isNot(contains('Reader chapter images loading finished')),
    );
    expect(find.byType(ReaderPage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exiting mid zoom reset releases each reader visit', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      ReaderSettingsStore.windowsShortcutsGuideSeenKey: true,
      ReaderSettingsStore.readingModeKey: 'right_to_left',
      ReaderSettingsStore.pinchToZoomKey: true,
    });

    for (var visit = 0; visit < 2; visit++) {
      await _mountReader(tester, _reader());
      await tester.pumpAndSettle();
      final host = _host(tester);
      final pageIndex = host.runtimeState.pageIndexNotifier;
      final page = tester.widget<PageView>(find.byType(PageView)).controller!;
      final transform = tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .transformationController!;
      transform.value = Matrix4.diagonal3Values(2, 2, 1);
      await tester.pump();
      host.onResetZoom();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(
        transform.value.getMaxScaleOnAxis(),
        allOf(greaterThan(1), lessThan(2)),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(find.byType(ReaderPage), findsNothing);
      expect(tester.takeException(), isNull);
      for (final controller in [pageIndex, page, transform]) {
        expect(() => controller.addListener(() {}), throwsFlutterError);
      }
    }
  });

  for (final selectQuality in [false, true]) {
    for (final systemBack in [false, true]) {
      testWidgets(
        'reader exits after quality menu: select=$selectQuality, systemBack=$systemBack',
        (tester) async {
          final settings = _SourceSettings();
          when(() => settings.presentationForSource('picacg')).thenReturn({
            'imageQualitySetting': 'quality',
            'imageQualityOptions': {
              'low': 'Low quality',
              'high': 'High quality',
            },
            'imageQualityDefault': 'low',
            'buttons': [
              {'id': 'imageQuality', 'location': 'reader'},
            ],
          });
          when(
            () => settings.updateSourceSetting(
              'picacg',
              'quality',
              'high',
              taskOrigin: any(named: 'taskOrigin'),
            ),
          ).thenAnswer((_) async {});
          final titleBar = _TitleBar();
          addTearDown(titleBar.dispose);
          await tester.pumpWidget(
            MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => withTestSourcePresentation(
                HazukiWindowsTitleBarScope(controller: titleBar, child: child!),
              ),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => _reader(sourceSettings: settings),
                      ),
                    ),
                    child: const Text('Open reader'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open reader'));
          await tester.pumpAndSettle();
          _host(tester).onOpenSettingsDrawer();
          await tester.pumpAndSettle();
          final dropdown = find.byType(HazukiMenuSettingTile<String>);
          await tester.scrollUntilVisible(
            dropdown,
            300,
            scrollable: find.descendant(
              of: find.byType(Drawer),
              matching: find.byType(Scrollable),
            ),
          );
          await tester.ensureVisible(dropdown);
          await tester.pumpAndSettle();
          await tester.tap(dropdown);
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('hazuki-frosted-menu-surface')),
            findsOneWidget,
          );
          expect(find.text('High quality').hitTestable(), findsOneWidget);
          if (selectQuality) {
            await tester.tap(find.text('High quality').hitTestable());
          } else if (systemBack) {
            await tester.binding.handlePopRoute();
          } else {
            await tester.tapAt(const Offset(10, 10));
          }
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('hazuki-frosted-menu-surface')),
            findsNothing,
          );
          if (selectQuality) {
            verify(
              () => settings.updateSourceSetting(
                'picacg',
                'quality',
                'high',
                taskOrigin: any(named: 'taskOrigin'),
              ),
            ).called(1);
          } else {
            verifyNever(
              () => settings.updateSourceSetting(
                'picacg',
                'quality',
                'high',
                taskOrigin: any(named: 'taskOrigin'),
              ),
            );
          }
          expect(
            find.descendant(
              of: dropdown,
              matching: find.text(
                selectQuality ? 'High quality' : 'Low quality',
              ),
            ),
            findsOneWidget,
          );
          final scaffold = tester.state<ScaffoldState>(
            find
                .ancestor(
                  of: find.byType(Drawer),
                  matching: find.byType(Scaffold),
                )
                .first,
          );
          expect(scaffold.isEndDrawerOpen, isTrue);
          if (systemBack) {
            await tester.binding.handlePopRoute();
          } else {
            await tester.scrollUntilVisible(
              find.byTooltip('Close'),
              -300,
              scrollable: find.descendant(
                of: find.byType(Drawer),
                matching: find.byType(Scrollable),
              ),
            );
            await tester.pumpAndSettle();
            await tester.tap(find.byTooltip('Close'));
          }
          await tester.pumpAndSettle();
          expect(scaffold.isEndDrawerOpen, isFalse);
          expect(find.byType(ReaderPage), findsOneWidget);

          if (systemBack) {
            await tester.binding.handlePopRoute();
          } else {
            _host(tester).onBackPressed();
          }
          await tester.pumpAndSettle();
          expect(find.byType(ReaderPage), findsNothing);
          expect(find.text('Open reader'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
      );
    }
  }

  for (final entry in ['android detail', 'windows detail', 'downloads']) {
    testWidgets('$entry keeps its route and return animation across chapters', (
      tester,
    ) async {
      var returned = false;
      final titleBar = _TitleBar();
      addTearDown(titleBar.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            platform: entry == 'windows detail'
                ? TargetPlatform.windows
                : TargetPlatform.android,
          ),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => withTestSourcePresentation(
            HazukiWindowsTitleBarScope(controller: titleBar, child: child!),
            activeSourceKey: 'picacg',
            catalog: const [
              SourceCatalogEntry(
                key: 'picacg',
                name: 'Pica',
                fileName: 'main.js',
                presentation: {'showComments': false},
              ),
            ],
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  final route = entry == 'downloads'
                      ? MaterialPageRoute<void>(builder: (_) => _reader())
                      : buildComicDetailDestinationRoute(
                          context,
                          (_) => _reader(),
                        );
                  await Navigator.of(context).push<void>(route);
                  returned = true;
                },
                child: const Text('Open reader'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open reader'));
      await tester.pumpAndSettle();
      final route = ModalRoute.of(tester.element(find.byType(ReaderPage)))!;
      final initialChapterRoute = ModalRoute.of(
        tester.element(find.byType(ReaderOverlayHost)),
      )!;
      final reverseDuration = route.reverseTransitionDuration;

      _host(tester).onNextChapter!();
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 110));
      final current = find.byWidgetPredicate(
        (widget) => widget is ReaderOverlayHost && widget.chapterIndex == 1,
      );
      expect(current, findsOneWidget);
      final chapterRoute = ModalRoute.of(tester.element(current))!;
      expect(chapterRoute, isA<MaterialPageRoute<void>>());
      expect(chapterRoute, isNot(same(initialChapterRoute)));
      final theme = Theme.of(tester.element(current));
      expect(
        chapterRoute.transitionDuration,
        theme.pageTransitionsTheme.builders[theme.platform]!.transitionDuration,
      );
      expect(chapterRoute.animation!.status, AnimationStatus.forward);
      expect(chapterRoute.animation!.value, inExclusiveRange(0, 1));
      expect(
        ModalRoute.of(tester.element(find.byType(ReaderPage))),
        same(route),
      );
      expect(returned, isFalse);
      await tester.pumpAndSettle();
      expect(find.byType(ReaderOverlayHost), findsOneWidget);
      expect(_host(tester).runtimeState.images, ['image-2']);

      // System back dismisses the nested sheet before exiting the reader.
      await _host(tester).onOpenChaptersPanel!();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(ExpandingChapterSheet), findsNothing);
      expect(_host(tester).chapterIndex, 1);
      expect(returned, isFalse);

      final scaffold = tester.state<ScaffoldState>(
        find
            .ancestor(
              of: find.byType(ReaderOverlayHost),
              matching: find.byType(Scaffold),
            )
            .first,
      );
      _host(tester).onOpenSettingsDrawer();
      await tester.pumpAndSettle();
      expect(scaffold.isEndDrawerOpen, isTrue);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(scaffold.isEndDrawerOpen, isFalse);
      expect(returned, isFalse);

      // Selecting the current chapter only dismisses the panel.
      await _host(tester).onOpenChaptersPanel!();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chapter 2'));
      await tester.pumpAndSettle();
      expect(_host(tester).chapterIndex, 1);

      await _host(tester).onOpenChaptersPanel!();
      await tester.pumpAndSettle();
      final sheet = find.byType(ExpandingChapterSheet);
      final initialSheet = tester.getRect(sheet);
      await tester.tap(find.text('Chapter 3'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 180));
      final expandingSheet = tester.getRect(sheet);
      expect(expandingSheet.top, lessThan(initialSheet.top));
      expect(expandingSheet.bottom, closeTo(initialSheet.bottom, 0.1));
      expect(expandingSheet.height, greaterThan(initialSheet.height));
      expect(_host(tester).chapterIndex, 1);
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);
      expect(_host(tester).chapterIndex, 2);
      expect(_host(tester).runtimeState.images, ['image-3']);

      _host(tester).onPreviousChapter!();
      await tester.pumpAndSettle();
      expect(_host(tester).chapterIndex, 1);
      expect(
        ModalRoute.of(tester.element(find.byType(ReaderPage))),
        same(route),
      );
      expect(route.reverseTransitionDuration, reverseDuration);
      expect(route.animation!.value, 1);
      expect(returned, isFalse);

      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump();
      await tester.pump(reverseDuration ~/ 2);
      expect(route.animation!.value, inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(find.text('Open reader'), findsOneWidget);
      expect(find.byType(ReaderPage), findsNothing);
      expect(returned, isTrue);
      expect(tester.takeException(), isNull);

      // Returning while the chapter transition is running must also be safe.
      returned = false;
      await tester.tap(find.text('Open reader'));
      await tester.pumpAndSettle();
      _host(tester).onNextChapter!();
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      tester.widget<ReaderOverlayHost>(current).onBackPressed();
      await tester.pumpAndSettle();
      expect(returned, isTrue);
      expect(find.text('Open reader'), findsOneWidget);
      expect(find.byType(ReaderPage), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
}

ReaderOverlayHost _host(WidgetTester tester) =>
    tester.widget<ReaderOverlayHost>(find.byType(ReaderOverlayHost));

Future<void> _mountReader(WidgetTester tester, ReaderPage reader) async {
  final titleBar = _TitleBar();
  addTearDown(titleBar.dispose);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => withTestSourcePresentation(
        HazukiWindowsTitleBarScope(controller: titleBar, child: child!),
      ),
      home: reader,
    ),
  );
}

ReaderPage _reader({
  SourceSettingsGateway? sourceSettings,
  SourceReaderGateway? sourceReader,
  bool offlineMode = true,
}) => ReaderPage(
  title: 'Comic',
  chapterTitle: 'Chapter 1',
  comicId: 'comic',
  epId: 'ep1',
  chapterIndex: 0,
  images: offlineMode ? const ['image-1'] : const [],
  sourceKey: 'picacg',
  offlineMode: offlineMode,
  offlineChapters: const [
    ReaderOfflineChapterData(
      epId: 'ep1',
      title: 'Chapter 1',
      index: 0,
      images: ['image-1'],
    ),
    ReaderOfflineChapterData(
      epId: 'ep2',
      title: 'Chapter 2',
      index: 1,
      images: ['image-2'],
    ),
    ReaderOfflineChapterData(
      epId: 'ep3',
      title: 'Chapter 3',
      index: 2,
      images: ['image-3'],
    ),
  ],
  dependencies: ReaderDependencies(
    sourceReader: sourceReader ?? sl<SourceReaderGateway>(),
    sourceSettings: sourceSettings ?? sl<SourceSettingsGateway>(),
    readingProgressService: sl<ReadingProgressService>(),
    downloader: sl<MangaDownloadService>(),
    taskControl: sourceReader == null ? null : sl<SourceTaskControlGateway>(),
  ),
  commentsWidgetBuilder:
      ({
        required comicId,
        required sourceKey,
        subId,
        chapterId,
        scrollController,
        onRequestTabFullscreen,
        interactionState,
      }) => const SizedBox.shrink(),
);

class _SourceSettings extends Mock implements SourceSettingsGateway {}

class _PendingReader extends Fake implements SourceReaderGateway {
  final images = Completer<List<String>>();
  final logs = <String>[];
  SourceTaskOrigin? origin;

  @override
  Future<List<String>> loadChapterImages({
    required String comicId,
    required String epId,
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  }) {
    origin = taskOrigin;
    return images.future;
  }

  @override
  void addReaderLog({
    required String level,
    required String title,
    Object? content,
    String source = 'reader',
  }) {
    logs.add(title);
  }
}

class _TitleBar extends ChangeNotifier implements WindowTitleBarControl {
  @override
  bool get useSystemTitleBar => true;
  @override
  bool get shouldShowCustomTitleBar => false;
  @override
  void suppressCustomTitleBar(Object owner) {}
  @override
  void releaseCustomTitleBarSuppression(Object owner) {}
  @override
  Future<void> updateUseSystemTitleBar(bool value) async {}
}
