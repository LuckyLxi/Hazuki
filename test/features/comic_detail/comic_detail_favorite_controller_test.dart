import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/comic_detail/repository/comic_detail_repository.dart';
import 'package:hazuki/features/comic_detail/support/comic_detail_favorite_controller.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/shared/favorites/favorite_folders_button_morph.dart';
import 'package:hazuki/shared/favorites/favorite_folders_morph_dialog.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements ComicDetailFeatureFacade {}

const _details = ComicDetailsData(
  id: 'comic-id',
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
);

void main() {
  for (final saveFails in [false, true]) {
    testWidgets('confirmed save starts before dismissal and survives disposal '
        '(saveFails=$saveFails)', (tester) async {
      final repository = _MockRepository();
      when(
        () => repository.favoriteSingleFolderForSingleComic,
      ).thenReturn(false);
      when(() => repository.isLogged).thenReturn(false);
      when(
        () => repository.loadLocalFavoriteFolders(
          comicId: _details.id,
          sourceKey: '',
        ),
      ).thenAnswer(
        (_) async => const FavoriteFoldersResult.success(
          folders: [
            FavoriteFolder(
              id: 'local-folder',
              name: 'Local folder',
              source: FavoriteFolderSource.local,
            ),
          ],
          favoritedFolderIds: {},
        ),
      );
      final saved = Completer<void>();
      var saveCalls = 0;
      when(
        () => repository.toggleLocalFavorite(
          details: _details,
          isAdding: true,
          folderId: 'local-folder',
        ),
      ).thenAnswer((_) {
        saveCalls++;
        return saved.future;
      });
      final controller = ComicDetailFavoriteController(repository: repository);
      var disposed = false;
      addTearDown(() {
        if (!disposed) controller.dispose();
      });
      late BuildContext pageContext;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              pageContext = context;
              return const Scaffold();
            },
          ),
        ),
      );
      var restorations = 0;
      var completed = false;
      final pending = controller
          .showFoldersDialog(
            pageContext,
            _details,
            (vm) => FavoriteFoldersMorphDialog(viewModel: vm),
            morphOrigin: const FavoriteFoldersMorphOrigin(
              rect: Rect.fromLTWH(10, 10, 48, 48),
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              icon: Icons.favorite_border,
            ),
            onDialogClosed: () => restorations++,
          )
          .then((_) => completed = true);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Local folder'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(saveCalls, 1);
      expect(controller.isBusy, isTrue);
      expect(find.byType(FavoriteFoldersMorphDialog), findsOneWidget);
      expect(restorations, 0);
      expect(completed, isFalse);

      // Leaving the detail page can dispose its controller while the
      // dialog's reverse transition and the repository request are pending.
      controller.dispose();
      disposed = true;
      if (saveFails) {
        saved.completeError(StateError('save failed'));
      } else {
        saved.complete();
      }
      await tester.pump(const Duration(milliseconds: 100));
      expect(restorations, 0);
      expect(completed, isFalse);
      await tester.pumpAndSettle();
      await pending;

      expect(saveCalls, 1);
      expect(restorations, 1);
      expect(find.byType(FavoriteFoldersMorphDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
