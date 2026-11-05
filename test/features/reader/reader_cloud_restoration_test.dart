import 'dart:async';
import 'dart:io';

import 'package:hazuki/shared/reading/reader_entry_position.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/app/service_locator.dart';
import 'package:hazuki/features/reader/support/reader_dependencies.dart';
import 'package:hazuki/features/reader/view/reader_page.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/manga_download/manga_download_service.dart';
import 'package:hazuki/services/reading_progress_service.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/shared/reading/reader_settings_store.dart';
import 'package:hazuki/shared/ui_flags.dart';
import 'package:hazuki/shared/windows/window_title_bar_control.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/source_presentation_fixtures.dart';
import '../../support/test_service_locator.dart';

class _Reader extends Fake
    implements
        SourceReaderGateway,
        SourceReadingProgressGateway,
        SourceCloudReadingGateway {
  @override
  Future<bool> usesCloudReading(
    String sourceKey, {
    SourceTaskOrigin? taskOrigin,
  }) async => true;
  final events = <Map<String, Object>>[];
  @override
  bool isLocalImagePath(String value) => true;
  @override
  String normalizeLocalImagePath(String value) => value;
  @override
  void addReaderLog({
    required String level,
    required String title,
    Object? content,
    String source = 'reader',
  }) {}
  @override
  void evictImageBytesFromMemory(
    Iterable<String> urls, {
    String sourceKey = '',
  }) {}
  @override
  Future<void> evictImageCacheEntries(
    Iterable<String> urls, {
    String sourceKey = '',
  }) async {}
  @override
  Future<void> reportReadingProgress(
    Map<String, Object> progress, {
    required String sourceKey,
    SourceTaskOrigin? taskOrigin,
  }) async {
    events.add(progress);
  }
}

class _NavigationReader extends _Reader {
  _NavigationReader(this.bytes);

  final Uint8List bytes;
  final imageRequests = <(String, String)>[];

  @override
  bool isLocalImagePath(String value) {
    imageRequests.add(('resolve', value));
    return false;
  }

  @override
  Future<PreparedChapterImageData> prepareChapterImageData(
    String imageUrl, {
    required String comicId,
    required String epId,
    bool useDiskCache = true,
    bool priority = false,
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  }) async => PreparedChapterImageData(
    bytes: bytes,
    extension: 'webp',
    wasProcessed: false,
    aspectRatio: 1,
  );

  @override
  Future<Uint8List> downloadImageBytes(
    String url, {
    String comicId = '',
    String epId = '',
    bool keepInMemory = false,
    bool useDiskCache = true,
    bool priority = false,
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  }) async {
    imageRequests.add(('download', url));
    return bytes;
  }
}

class _DelayedProgress extends Fake implements ReadingProgressService {
  final position = Completer<Map<String, dynamic>?>();
  bool requested = false;

  @override
  Future<Map<String, dynamic>?> load({
    required String comicId,
    required String sourceKey,
  }) {
    requested = true;
    return position.future;
  }

  @override
  Future<void> save({
    required String comicId,
    required String sourceKey,
    required String epId,
    required String title,
    required int chapterIndex,
    required int pageIndex,
  }) async {}
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

void main() {
  testWidgets(
    'navigation wins over a pending restore and prefetch follows no-image mode',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        ReaderSettingsStore.readingModeKey: 'right_to_left',
        ReaderSettingsStore.windowsShortcutsGuideSeenKey: true,
        ReaderSettingsStore.restorePagePositionKey: true,
      });
      await ensureTestServiceLocator();
      final previous = hazukiNoImageModeNotifier.value;
      hazukiNoImageModeNotifier.value = true;
      addTearDown(() => hazukiNoImageModeNotifier.value = previous);
      final data = await rootBundle.load(
        'assets/images/downloaded_cover_placeholder.webp',
      );
      final reader = _NavigationReader(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      final progress = _DelayedProgress();
      final titleBar = _TitleBar();
      addTearDown(titleBar.dispose);
      final images = List.generate(6, (index) => 'https://example.test/$index');
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => withTestSourcePresentation(
            HazukiWindowsTitleBarScope(controller: titleBar, child: child!),
          ),
          home: ReaderPage(
            title: 'Comic',
            chapterTitle: 'Chapter',
            comicId: 'c',
            epId: 'e',
            chapterIndex: 0,
            images: images,
            sourceKey: 'jm',
            offlineMode: true,
            dependencies: ReaderDependencies(
              sourceReader: reader,
              sourceSettings: sl<SourceSettingsGateway>(),
              readingProgressService: progress,
              downloader: sl<MangaDownloadService>(),
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
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(progress.requested, isTrue);
      final controller = tester
          .widget<PageView>(find.byType(PageView))
          .controller!;

      // Isolate requests from navigation after the initial image setup.
      reader.imageRequests.clear();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(controller.page, 1);
      expect(reader.imageRequests, isEmpty);

      progress.position.complete({'epId': 'e', 'imagePage': 5});
      await tester.pumpAndSettle();
      expect(controller.page, 1);

      hazukiNoImageModeNotifier.value = false;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 240));
      expect(controller.page, 2);
      expect(reader.imageRequests.first, ('resolve', images[2]));
      expect(reader.imageRequests, contains(('download', images[3])));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  for (final targetPage in [5, 99]) {
    final expectedTarget = targetPage.clamp(1, 6);
    for (final mode in ['right_to_left', 'top_to_bottom']) {
      for (final doublePage in [false, true]) {
        testWidgets(
          '$mode double=$doublePage target=$targetPage restores original website page before the first upload',
          (tester) async {
            SharedPreferences.setMockInitialValues({
              ReaderSettingsStore.readingModeKey: mode,
              ReaderSettingsStore.doublePageModeKey: doublePage,
              ReaderSettingsStore.windowsShortcutsGuideSeenKey: true,
              ReaderSettingsStore.restorePagePositionKey: true,
            });
            await ensureTestServiceLocator();
            final previous = hazukiNoImageModeNotifier.value;
            hazukiNoImageModeNotifier.value = false;
            addTearDown(() => hazukiNoImageModeNotifier.value = previous);
            final files = (await tester.runAsync(() async {
              final directory = await Directory.systemTemp.createTemp(
                'hazuki-progress-',
              );
              final images = <String>[];
              for (var i = 0; i < 6; i++) {
                images.add(
                  (await File(
                    'assets/images/downloaded_cover_placeholder.webp',
                  ).copy('${directory.path}/$i.png')).path,
                );
              }
              return (directory: directory, images: images);
            }))!;
            final directory = files.directory;
            final images = files.images;
            final reader = _Reader();
            final titleBar = _TitleBar();
            addTearDown(titleBar.dispose);
            await tester.pumpWidget(
              MaterialApp(
                locale: const Locale('en'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => withTestSourcePresentation(
                  HazukiWindowsTitleBarScope(
                    controller: titleBar,
                    child: child!,
                  ),
                ),
                home: ReaderEntryPosition(
                  progress: {
                    'epId': 'e',
                    'imagePage': targetPage,
                    'cloud': true,
                  },
                  child: ReaderPage(
                    title: 'Comic',
                    chapterTitle: 'Chapter',
                    comicId: 'c',
                    epId: 'e',
                    chapterIndex: 0,
                    images: images,
                    sourceKey: 'jm',
                    dependencies: ReaderDependencies(
                      sourceReader: reader,
                      sourceSettings: sl<SourceSettingsGateway>(),
                      readingProgressService: sl<ReadingProgressService>(),
                      downloader: sl<MangaDownloadService>(),
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
                  ),
                ),
              ),
            );
            Future<void> decode() async {
              for (var i = 0; i < 12; i++) {
                await tester.pump(const Duration(milliseconds: 50));
                await tester.runAsync(
                  () => Future<void>.delayed(const Duration(milliseconds: 20)),
                );
              }
            }

            await decode();
            await decode();
            expect(reader.events, isNotEmpty);
            expect(
              reader.events.first['visiblePages'],
              contains(expectedTarget),
            );
            expect(reader.events.first['page'], greaterThan(1));
            expect(reader.events.first['totalPages'], 6);
            if (mode == 'right_to_left') {
              expect(
                reader.events.first['visiblePages'],
                doublePage ? [5, 6] : [expectedTarget],
              );
              final page = tester.widget<PageView>(find.byType(PageView));
              final future = page.controller!.animateToPage(
                1,
                duration: const Duration(milliseconds: 220),
                curve: Curves.linear,
              );
              // Starting an animation has not changed the visible page yet.
              expect(
                reader.events.last['page'],
                doublePage ? 5 : expectedTarget,
              );
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 240));
              await future;
            } else {
              final list = tester.widget<ListView>(find.byType(ListView).first);
              final controller = list.controller!;
              controller.jumpTo(controller.position.maxScrollExtent);
              await tester.pump();
            }
            await decode();
            await tester.pump(const Duration(seconds: 5));
            expect(reader.events.last['page'], greaterThan(1));
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.inactive,
            );
            await tester.pump();
            expect(reader.events.last['reason'], 'background');
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.resumed,
            );
            final localBefore = await sl<ReadingProgressService>().load(
              comicId: 'c',
              sourceKey: 'jm',
            );
            final before = reader.events.last['page'];
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
            expect(reader.events.last['reason'], 'exit');
            expect(reader.events.last['page'], before);
            expect(
              await sl<ReadingProgressService>().load(
                comicId: 'c',
                sourceKey: 'jm',
              ),
              localBefore,
            );
            expect(tester.takeException(), isNull);
            await tester.runAsync(() => directory.delete(recursive: true));
          },
        );
      }
    }
  }
}
