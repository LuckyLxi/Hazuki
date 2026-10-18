import 'dart:io';

import 'package:flutter/material.dart';
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
import 'package:hazuki/shared/window/window_title_bar_control.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/source_presentation_fixtures.dart';
import '../../support/test_service_locator.dart';

class _Reader extends Fake
    implements SourceReaderGateway, SourceReadingProgressGateway {
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
  }) async {
    events.add(progress);
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

void main() {
  for (final mode in ['right_to_left', 'top_to_bottom']) {
    for (final doublePage in [false, true]) {
      testWidgets(
        '$mode double=$doublePage reports visible images and never navigation targets',
        (tester) async {
          SharedPreferences.setMockInitialValues({
            ReaderSettingsStore.readingModeKey: mode,
            ReaderSettingsStore.doublePageModeKey: doublePage,
            ReaderSettingsStore.windowsShortcutsGuideSeenKey: true,
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
                  'assets/images/downloaded_cover_placeholder.png',
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
          expect(reader.events.first['page'], 1);
          expect(reader.events.first['totalPages'], 6);
          if (mode == 'right_to_left') {
            expect(
              reader.events.first['visiblePages'],
              doublePage ? [1, 2] : [1],
            );
            final page = tester.widget<PageView>(find.byType(PageView));
            final future = page.controller!.animateToPage(
              1,
              duration: const Duration(milliseconds: 220),
              curve: Curves.linear,
            );
            // Starting an animation has not changed the visible page yet.
            expect(reader.events.last['page'], 1);
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
          final before = reader.events.last['page'];
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          expect(reader.events.last['reason'], 'exit');
          expect(reader.events.last['page'], before);
          expect(tester.takeException(), isNull);
          await tester.runAsync(() => directory.delete(recursive: true));
        },
      );
    }
  }
}
