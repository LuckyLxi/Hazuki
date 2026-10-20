import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/favorite/view/favorite_page.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/local_favorites/local_favorites_contracts.dart';
import 'package:hazuki/services/local_favorites/local_favorites_preferences_store.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Source extends Mock implements SourceFavoriteGateway {}

class _Local extends Mock implements LocalFavoritesRepository {}

class _Images extends Mock implements SourceImageGateway {}

void main() {
  late _Source source;
  late String folderName;
  late bool supported;
  late String activeSource;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    source = _Source();
    folderName = 'Shelf';
    supported = true;
    activeSource = 'test';
    when(() => source.activeSourceKey).thenAnswer((_) => activeSource);
    when(() => source.isLogged).thenReturn(true);
    when(
      () => source.sourceRuntimeState,
    ).thenReturn(const SourceRuntimeState.idle());
    when(() => source.supportFavoriteFolderRename).thenAnswer((_) => supported);
    when(() => source.supportFavoriteFolderLoad).thenReturn(true);
    when(() => source.supportFavoriteFolderDelete).thenReturn(false);
    when(() => source.supportFavoriteFolderAdd).thenReturn(false);
    when(() => source.supportFavoriteSortOrder).thenReturn(false);
    when(() => source.favoriteSortOrder).thenReturn('');
    when(() => source.favoriteSortOrders).thenReturn([]);
    when(
      () => source.cloudFavoritesChangedStream,
    ).thenAnswer((_) => const Stream<void>.empty());
    when(source.ensureInitialized).thenAnswer((_) async {});
    when(source.loadFavoriteFolders).thenAnswer(
      (_) async => FavoriteFoldersResult.success(
        folders: [
          const FavoriteFolder(id: '0', name: '__favorite_all__'),
          FavoriteFolder(id: 'shelf', name: folderName),
        ],
        favoritedFolderIds: const {},
      ),
    );
    when(
      () =>
          source.loadFavoriteComics(page: 1, folderId: any(named: 'folderId')),
    ).thenAnswer(
      (_) async => FavoriteComicsResult.success(const [], maxPage: 1),
    );
    when(
      () => source.renameFavoriteFolder('shelf', any(), sourceKey: 'test'),
    ).thenAnswer((call) async {
      folderName = call.positionalArguments[1] as String;
    });
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        theme: ThemeData(platform: TargetPlatform.android),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: FavoritePage(
            sourceService: source,
            localFavoritesRepository: _Local(),
            localFavoritesPreferences:
                SharedPreferencesLocalFavoritesPreferencesStore(),
            imageGateway: _Images(),
            authVersion: 0,
            onComicTap: (_, _) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'supported cloud folders reuse the rename dialog and refresh the label',
    (tester) async {
      await pumpPage(tester);
      await tester.tap(find.text('Shelf'));
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Shelf'));
      await tester.pumpAndSettle();
      expect(find.text('Rename favorite folder'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Shelf',
      );
      await tester.enterText(find.byType(TextField), '  Renamed shelf  ');
      await tester.tap(find.widgetWithText(FilledButton, 'OK'));
      await tester.pumpAndSettle();
      verify(
        () => source.renameFavoriteFolder(
          'shelf',
          'Renamed shelf',
          sourceKey: 'test',
        ),
      ).called(1);
      expect(find.text('Renamed shelf'), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(
              find.widgetWithText(ChoiceChip, 'Renamed shelf'),
            )
            .selected,
        isTrue,
      );
    },
  );

  testWidgets('unsupported plugins and the all folder have no rename gesture', (
    tester,
  ) async {
    supported = false;
    await pumpPage(tester);
    await tester.longPress(find.text('Shelf'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    supported = true;
    await tester.pumpWidget(const SizedBox());
    await pumpPage(tester);
    await tester.longPress(find.text('All'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets(
    'unchanged names and a source switch while editing do not submit',
    (tester) async {
      await pumpPage(tester);
      await tester.longPress(find.text('Shelf'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '  Shelf  ');
      await tester.tap(find.widgetWithText(FilledButton, 'OK'));
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Shelf'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'New name');
      activeSource = 'other';
      await tester.tap(find.widgetWithText(FilledButton, 'OK'));
      await tester.pumpAndSettle();
      verifyNever(
        () => source.renameFavoriteFolder(
          any(),
          any(),
          sourceKey: any(named: 'sourceKey'),
        ),
      );
    },
  );
}
