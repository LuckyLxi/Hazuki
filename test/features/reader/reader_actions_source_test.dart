import '../../support/source_presentation_fixtures.dart';
import 'package:hazuki/features/reader/view/reader_comments_sheet.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hazuki/features/reader/support/reader_actions_controller.dart';
import 'package:hazuki/features/reader/support/reader_page_context.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/manga_download/manga_download_commands.dart';
import 'package:hazuki/services/source/source_capabilities.dart';

class _Source extends Mock implements SourceReaderGateway {}

class _Downloader extends Mock implements MangaDownloadCommands {}

class _Details extends Mock implements ComicDetailsData {}

void main() {
  late _Source source;
  ReaderActionsController controller({
    bool offline = false,
    String sourceKey = 'picacg',
    BuildContext? context,
  }) => ReaderActionsController(
    context: () =>
        context ?? (throw StateError('No UI context needed to load details')),
    isMounted: () => true,
    updateState: (update) => update(),
    logEvent: (_, {level = 'info', source = 'reader_ui', content}) {},
    logPayload: ([extra]) => extra ?? {},
    sourceReader: source,
    pageContext: ReaderPageContext(
      title: 'Title',
      chapterTitle: 'Chapter 1',
      comicId: 'comic',
      epId: 'ep1',
      chapterIndex: 0,
      images: const [],
      sourceKey: sourceKey,
      offlineMode: offline,
      offlineChapters: const [
        ReaderOfflineChapterData(
          epId: 'ep2',
          title: 'Chapter 2',
          index: 1,
          images: [],
        ),
        ReaderOfflineChapterData(
          epId: 'ep1',
          title: 'Chapter 1',
          index: 0,
          images: [],
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
    onChapterChanged: (_, {bool animate = true}) {},
    downloader: _Downloader(),
  );

  setUp(() {
    source = _Source();
  });

  for (final declaration in [null, false, true]) {
    for (final offline in [false, true]) {
      testWidgets(
        'reader comments declaration=$declaration, offline=$offline',
        (tester) async {
          const details = ComicDetailsData(
            id: 'comic',
            title: 'Title',
            subTitle: '',
            cover: '',
            description: '',
            updateTime: '',
            likesCount: '',
            chapters: {},
            tags: {},
            recommend: [],
            isFavorite: false,
            subId: '',
            sourceKey: 'picacg',
          );
          when(
            () => source.loadComicDetails('comic', sourceKey: 'picacg'),
          ).thenAnswer((_) async => details);
          late ReaderActionsController actions;
          late BuildContext pageContext;
          await tester.pumpWidget(
            MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => withTestSourcePresentation(
                child!,
                activeSourceKey: 'other',
                catalog: [
                  SourceCatalogEntry(
                    key: 'picacg',
                    name: 'Pica',
                    fileName: 'main.js',
                    presentation: {'showComments': ?declaration},
                  ),
                  const SourceCatalogEntry(
                    key: 'other',
                    name: 'Other',
                    fileName: 'main.js',
                    presentation: {'showComments': true},
                  ),
                ],
              ),
              home: Scaffold(
                body: Builder(
                  builder: (context) {
                    pageContext = context;
                    actions = controller(context: context, offline: offline);
                    return const SizedBox();
                  },
                ),
              ),
            ),
          );
          final enabled = declaration == true && !offline;
          expect(actions.commentsEnabled, enabled);
          final pending = actions.openCommentsSheet();
          await tester.pumpAndSettle();
          expect(
            find.byType(ReaderCommentsSheet),
            enabled ? findsOneWidget : findsNothing,
          );
          if (enabled) {
            verify(
              () => source.loadComicDetails('comic', sourceKey: 'picacg'),
            ).called(1);
            Navigator.of(pageContext).pop();
            await tester.pumpAndSettle();
          } else {
            verifyZeroInteractions(source);
          }
          await pending;
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  test(
    'online details use the page source and cache successful responses',
    () async {
      final details = _Details();
      when(
        () => source.loadComicDetails('comic', sourceKey: 'picacg'),
      ).thenAnswer((_) async => details);
      final actions = controller();
      expect(await actions.loadReaderComicDetails(), same(details));
      expect(await actions.loadReaderComicDetails(), same(details));
      verify(
        () => source.loadComicDetails('comic', sourceKey: 'picacg'),
      ).called(1);
    },
  );

  test('empty source identity is passed through unchanged', () async {
    final details = _Details();
    when(
      () => source.loadComicDetails('comic', sourceKey: ''),
    ).thenAnswer((_) async => details);
    expect(
      await controller(sourceKey: '').loadReaderComicDetails(),
      same(details),
    );
    verify(() => source.loadComicDetails('comic', sourceKey: '')).called(1);
  });

  test('failed loading can be retried without a poisoned cache', () async {
    final details = _Details();
    when(
      () => source.loadComicDetails('comic', sourceKey: 'picacg'),
    ).thenThrow(StateError('unavailable'));
    final actions = controller();
    await expectLater(actions.loadReaderComicDetails(), throwsStateError);
    when(
      () => source.loadComicDetails('comic', sourceKey: 'picacg'),
    ).thenAnswer((_) async => details);
    expect(await actions.loadReaderComicDetails(), same(details));
  });

  test(
    'offline details preserve chapter order without accessing a source',
    () async {
      final details = await controller(offline: true).loadReaderComicDetails();
      expect(details.id, 'comic');
      expect(details.sourceKey, 'picacg');
      expect(details.chapters.keys, ['ep1', 'ep2']);
      expect(details.chapters.values, ['Chapter 1', 'Chapter 2']);
      verifyZeroInteractions(source);
    },
  );
}
