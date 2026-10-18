import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/reader/support/reader_actions_controller.dart';
import 'package:hazuki/features/reader/support/reader_page_context.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/manga_download/manga_download_commands.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/widgets/chapters_panel_sheet.dart';

class _Reader extends Fake implements SourceReaderGateway {
  @override
  Future<ComicDetailsData> loadComicDetails(
    String id, {
    String sourceKey = '',
  }) async => _details;
}

class _Downloader extends Fake implements MangaDownloadCommands {}

const _details = ComicDetailsData(
  id: 'comic',
  title: 'Comic',
  subTitle: '',
  cover: '',
  description: '',
  updateTime: '',
  likesCount: '',
  chapters: {'10': 'First', '2': 'Second', '1': 'Alternative'},
  chapterGroups: [
    ComicChapterGroup(
      id: 'a',
      title: 'Serial',
      chapters: {'10': 'First', '2': 'Second'},
    ),
    ComicChapterGroup(id: 'b', title: 'Other', chapters: {'1': 'Alternative'}),
  ],
  tags: {},
  recommend: [],
  isFavorite: false,
  subId: '',
);

void main() {
  testWidgets(
    'adjacent chapter navigation stops at group boundaries and retains global indices',
    (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (c) {
              context = c;
              return const Scaffold();
            },
          ),
        ),
      );
      final changed = <ReaderPageContext>[];
      final controller = ReaderActionsController(
        context: () => context,
        isMounted: () => true,
        updateState: (fn) => fn(),
        logEvent: (_, {level = 'info', source = 'reader', content}) {},
        logPayload: ([extra]) => extra ?? {},
        sourceReader: _Reader(),
        pageContext: ReaderPageContext(
          title: 'Comic',
          chapterTitle: 'Second',
          comicId: 'comic',
          epId: '2',
          chapterIndex: 1,
          images: const [],
          sourceKey: 'sample',
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
        onChapterChanged: (chapter, {animate = true}) => changed.add(chapter),
        downloader: _Downloader(),
      );
      await controller.jumpToAdjacentChapter(1);
      expect(changed, isEmpty);
      await controller.jumpToAdjacentChapter(-1);
      expect(changed.single.epId, '10');
      expect(changed.single.chapterIndex, 0);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
    },
  );

  testWidgets(
    'reader chapter picker opens on the current group and reports a global index',
    (tester) async {
      int? index;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ChaptersPanelSheet(
              details: _details,
              initialChapterId: '1',
              onChapterTap: (_, _, i) => index = i,
              onDownloadConfirm: (_) {},
            ),
          ),
        ),
      );
      expect(find.text('Alternative'), findsOneWidget);
      expect(find.text('First'), findsNothing);
      await tester.tap(find.text('Alternative'));
      expect(index, 2);
    },
  );

  testWidgets(
    'offline navigation follows group order across reused chapter indices',
    (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (c) {
              context = c;
              return const Scaffold();
            },
          ),
        ),
      );
      final changed = <ReaderPageContext>[];
      ReaderActionsController controller(String epId, int chapterIndex) =>
          ReaderActionsController(
            context: () => context,
            isMounted: () => true,
            updateState: (fn) => fn(),
            logEvent: (_, {level = 'info', source = 'reader', content}) {},
            logPayload: ([extra]) => extra ?? {},
            sourceReader: _Reader(),
            pageContext: ReaderPageContext(
              title: 'Comic',
              chapterTitle: epId,
              comicId: 'comic',
              epId: epId,
              chapterIndex: chapterIndex,
              images: const [],
              sourceKey: 'sample',
              offlineMode: true,
              offlineChapters: const [
                ReaderOfflineChapterData(
                  epId: 'a1',
                  title: 'A1',
                  index: 0,
                  images: [],
                  groupId: 'a',
                  groupTitle: 'Serial',
                ),
                ReaderOfflineChapterData(
                  epId: 'a2',
                  title: 'A2',
                  index: 1,
                  images: [],
                  groupId: 'a',
                  groupTitle: 'Serial',
                ),
                ReaderOfflineChapterData(
                  epId: 'b1',
                  title: 'B1',
                  index: 0,
                  images: [],
                  groupId: 'b',
                  groupTitle: 'Other',
                ),
              ],
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
            onChapterChanged: (chapter, {animate = true}) =>
                changed.add(chapter),
            downloader: _Downloader(),
          );

      final first = controller('a1', 0);
      final details = await first.loadReaderComicDetails();
      expect(details.chapters.keys, ['a1', 'b1', 'a2']);
      await first.jumpToAdjacentChapter(1);
      expect(changed.single.epId, 'a2');
      expect(changed.single.chapterIndex, 2);

      changed.clear();
      await controller('a2', 2).jumpToAdjacentChapter(-1);
      expect(changed.single.epId, 'a1');
      expect(changed.single.chapterIndex, 0);

      changed.clear();
      await first.jumpToAdjacentChapter(-1);
      await controller('a2', 2).jumpToAdjacentChapter(1);
      await controller('b1', 1).jumpToAdjacentChapter(-1);
      await controller('b1', 1).jumpToAdjacentChapter(1);
      expect(changed, isEmpty);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
    },
  );
}
