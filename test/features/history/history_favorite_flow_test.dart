import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/history/history.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/local_favorites/local_favorites_contracts.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/shared/favorites/favorite_folders_morph_dialog.dart';
import 'package:mocktail/mocktail.dart';

class _Source extends Mock implements SourceComicDetailGateway {}

class _LocalFavorites extends Mock implements LocalFavoritesRepository {}

const _comic = ExploreComic(
  id: 'comic',
  title: 'Comic',
  subTitle: '',
  cover: '',
  sourceKey: 'a',
);

const _details = ComicDetailsData(
  id: 'comic',
  title: 'Comic',
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
  sourceKey: 'a',
);

void main() {
  late _Source source;
  late _LocalFavorites local;
  late String activeSource;
  late AppLocalizations strings;
  final dialog = find.byType(FavoriteFoldersMorphDialog);

  setUp(() {
    source = _Source();
    local = _LocalFavorites();
    activeSource = 'b';
    when(() => source.activeSourceKey).thenAnswer((_) => activeSource);
    when(
      () => source.loadComicDetails('comic', sourceKey: 'a'),
    ).thenAnswer((_) async => _details);
    when(() => source.isLoggedForSource('a')).thenReturn(true);
    when(() => source.supportFavoriteFolderLoadForSource('a')).thenReturn(true);
    when(() => source.supportFavoriteToggleForSource('a')).thenReturn(true);
    when(() => source.supportFavoriteFolderAddForSource('a')).thenReturn(false);
    when(
      () => source.supportFavoriteFolderDeleteForSource('a'),
    ).thenReturn(false);
    when(
      () => source.favoriteSingleFolderForSingleComicForSource('a'),
    ).thenReturn(false);
    when(
      () => source.loadFavoriteFolders(comicId: 'comic', sourceKey: 'a'),
    ).thenAnswer(
      (_) async => const FavoriteFoldersResult.success(
        folders: [FavoriteFolder(id: 'cloud', name: 'Cloud list')],
        favoritedFolderIds: {},
      ),
    );
    when(
      () => local.loadFavoriteFolders(comicId: 'comic', sourceKey: 'a'),
    ).thenAnswer(
      (_) async => const FavoriteFoldersResult.success(
        folders: [
          FavoriteFolder(
            id: 'local',
            name: 'Local list',
            source: FavoriteFolderSource.local,
          ),
        ],
        favoritedFolderIds: {},
      ),
    );
    when(
      () => source.toggleFavorite(
        comicId: 'comic',
        isAdding: true,
        folderId: 'cloud',
        sourceKey: 'a',
      ),
    ).thenAnswer((_) async {});
    when(
      () => local.toggleFavorite(
        details: _details,
        isAdding: true,
        folderId: 'local',
      ),
    ).thenAnswer((_) async {});
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              strings = AppLocalizations.of(context)!;
              return TextButton(
                onPressed: () => showHistoryFavoriteDialog(
                  context,
                  _comic,
                  source: source,
                  localFavorites: local,
                ),
                child: const Text('Open favorites'),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open favorites'));
    await tester.pumpAndSettle();
  }

  Future<void> finishPrompt(WidgetTester tester, String message) async {
    expect(find.text(message), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'reads and writes the comic source after the active source changes',
    (tester) async {
      final pending = Completer<ComicDetailsData>();
      when(
        () => source.loadComicDetails('comic', sourceKey: 'a'),
      ).thenAnswer((_) => pending.future);
      await open(tester);
      expect(dialog, findsNothing);
      activeSource = 'c';
      pending.complete(_details);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cloud list'));
      await tester.ensureVisible(find.text('Local list'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Local list'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(strings.commonSave));
      await tester.pumpAndSettle();

      verify(
        () => source.loadFavoriteFolders(comicId: 'comic', sourceKey: 'a'),
      ).called(1);
      verify(
        () => local.loadFavoriteFolders(comicId: 'comic', sourceKey: 'a'),
      ).called(1);
      verify(
        () => source.toggleFavorite(
          comicId: 'comic',
          isAdding: true,
          folderId: 'cloud',
          sourceKey: 'a',
        ),
      ).called(1);
      verify(
        () => local.toggleFavorite(
          details: _details,
          isAdding: true,
          folderId: 'local',
        ),
      ).called(1);
      await finishPrompt(tester, strings.comicDetailFavoriteSettingsUpdated);
    },
  );

  for (final cancel in [true, false]) {
    testWidgets(
      cancel
          ? 'cancel discards changes'
          : 'saving without changes skips writes',
      (tester) async {
        if (!cancel) {
          when(
            () => source.loadFavoriteFolders(comicId: 'comic', sourceKey: 'a'),
          ).thenAnswer(
            (_) async => const FavoriteFoldersResult.success(
              folders: [FavoriteFolder(id: 'cloud', name: 'Cloud list')],
              favoritedFolderIds: {'cloud'},
            ),
          );
        }
        await open(tester);
        final viewModel = tester
            .widget<FavoriteFoldersMorphDialog>(dialog)
            .viewModel;
        if (cancel) {
          await tester.tap(find.text('Cloud list'));
          await tester.pumpAndSettle();
        }
        await tester.tap(
          cancel
              ? find.widgetWithText(OutlinedButton, strings.commonClose)
              : find.text(strings.commonSave),
        );
        await tester.pumpAndSettle();

        expect(dialog, findsNothing);
        verifyNever(
          () => source.toggleFavorite(
            comicId: 'comic',
            isAdding: any(named: 'isAdding'),
            folderId: 'cloud',
            sourceKey: 'a',
          ),
        );
        verifyNever(
          () => local.toggleFavorite(
            details: _details,
            isAdding: any(named: 'isAdding'),
            folderId: 'local',
          ),
        );
        expect(() => viewModel.addListener(() {}), throwsFlutterError);
      },
    );
  }

  testWidgets('reports details load failure without opening the dialog', (
    tester,
  ) async {
    final error = StateError('details unavailable');
    when(
      () => source.loadComicDetails('comic', sourceKey: 'a'),
    ).thenAnswer((_) async => throw error);
    await open(tester);

    expect(dialog, findsNothing);
    await finishPrompt(tester, strings.historyFavoriteFailed('$error'));
  });

  testWidgets('reports submit failure after closing the dialog', (
    tester,
  ) async {
    final error = Exception();
    when(
      () => source.toggleFavorite(
        comicId: 'comic',
        isAdding: true,
        folderId: 'cloud',
        sourceKey: 'a',
      ),
    ).thenAnswer((_) async => throw error);
    await open(tester);
    final viewModel = tester
        .widget<FavoriteFoldersMorphDialog>(dialog)
        .viewModel;
    await tester.tap(find.text('Cloud list'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.commonSave));
    await tester.pumpAndSettle();

    expect(dialog, findsNothing);
    expect(() => viewModel.addListener(() {}), throwsFlutterError);
    await finishPrompt(
      tester,
      strings.comicDetailFavoriteSettingsUpdateFailed('$error'),
    );
  });

  testWidgets('ignores details arriving after the page unmounts', (
    tester,
  ) async {
    final pending = Completer<ComicDetailsData>();
    when(
      () => source.loadComicDetails('comic', sourceKey: 'a'),
    ).thenAnswer((_) => pending.future);
    await open(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete(_details);
    await tester.pumpAndSettle();

    verifyZeroInteractions(local);
    expect(tester.takeException(), isNull);
  });
}
