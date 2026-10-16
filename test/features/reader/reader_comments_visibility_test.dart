import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hazuki/app/service_locator.dart';
import 'package:hazuki/features/reader/support/reader_dependencies.dart';
import 'package:hazuki/features/reader/view/reader_overlay_host.dart';
import 'package:hazuki/features/reader/view/reader_page.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/manga_download/manga_download_service.dart';
import 'package:hazuki/services/reading_progress_service.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/shared/ui_flags.dart';
import 'package:hazuki/shared/reading/reader_settings_store.dart';
import 'package:hazuki/shared/window/window_title_bar_control.dart';

import '../../support/source_presentation_fixtures.dart';
import '../../support/test_service_locator.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      hazukiNoImageModePreferenceKey: true,
      ReaderSettingsStore.windowsShortcutsGuideSeenKey: true,
    });
    await ensureTestServiceLocator();
    final previous = hazukiNoImageModeNotifier.value;
    hazukiNoImageModeNotifier.value = true;
    addTearDown(() => hazukiNoImageModeNotifier.value = previous);
  });

  for (final declaration in [null, false, true]) {
    for (final offline in [false, true]) {
      testWidgets('reader entry: showComments=$declaration, offline=$offline', (
        tester,
      ) async {
        final titleBar = _TitleBar();
        addTearDown(titleBar.dispose);
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => withTestSourcePresentation(
              HazukiWindowsTitleBarScope(controller: titleBar, child: child!),
              activeSourceKey: 'picacg',
              catalog: [
                SourceCatalogEntry(
                  key: 'picacg',
                  name: 'Pica',
                  fileName: 'main.js',
                  presentation: {'showComments': ?declaration},
                ),
              ],
            ),
            home: ReaderPage(
              title: 'Comic',
              chapterTitle: 'Chapter',
              comicId: 'comic',
              epId: 'chapter',
              chapterIndex: 0,
              images: const ['fixture-image'],
              sourceKey: 'picacg',
              offlineMode: offline,
              dependencies: ReaderDependencies(
                sourceReader: sl<SourceReaderGateway>(),
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
        await tester.pumpAndSettle();
        final host = tester.widget<ReaderOverlayHost>(
          find.byType(ReaderOverlayHost),
        );
        host.updateState(() => host.runtimeState.setControlsVisible(true));
        await tester.pumpAndSettle();
        expect(
          find.byIcon(Icons.mode_comment_outlined),
          declaration == true && !offline ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      });
    }
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
