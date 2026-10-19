import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/favorite/view/favorite_page.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/local_favorites/local_favorites_contracts.dart';
import 'package:hazuki/services/local_favorites/local_favorites_preferences_store.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/shared/appearance/appearance_settings.dart';
import 'package:hazuki/shared/appearance/appearance_settings_scope.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Source extends Mock implements SourceFavoriteGateway {}

class _Local extends Mock implements LocalFavoritesRepository {}

class _Images extends Mock implements SourceImageGateway {}

class _Appearance extends ChangeNotifier implements AppearanceSettingsSource {
  _Appearance(FavoriteLayout layout)
    : settings = AppearanceSettingsData(
        themeMode: ThemeMode.light,
        oledPureBlack: false,
        dynamicColor: false,
        presetIndex: 0,
        displayModeRaw: 'native:auto',
        comicDetailDynamicColor: false,
        useSystemFont: true,
        favoriteLayout: layout,
      );

  @override
  final AppearanceSettingsData settings;
}

final _comics = List.generate(
  28,
  (index) => ExploreComic(
    id: 'comic-$index',
    sourceKey: 'test',
    title: 'Comic $index',
    subTitle: '',
    cover: '',
  ),
);

Finder _tile(int index) => find.byKey(ValueKey('comic-$index-cloud'));

Finder _opacity(int index) =>
    find.descendant(of: _tile(index), matching: find.byType(FadeTransition));

double _progress(WidgetTester tester, int index) =>
    tester.widget<FadeTransition>(_opacity(index)).opacity.value;

Offset _offset(WidgetTester tester, int index) => tester
    .widget<SlideTransition>(
      find.descendant(of: _tile(index), matching: find.byType(SlideTransition)),
    )
    .position
    .value;

Future<_Source> _pumpPage(
  WidgetTester tester,
  FavoriteLayout layout, {
  bool paginated = false,
  double viewportHeight = 420,
  bool settle = true,
}) async {
  tester.view.physicalSize = Size(390, viewportHeight);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  final source = _Source();
  when(() => source.activeSourceKey).thenReturn('test');
  when(() => source.isLogged).thenReturn(true);
  when(
    () => source.sourceRuntimeState,
  ).thenReturn(const SourceRuntimeState.idle());
  when(() => source.supportFavoriteSortOrder).thenReturn(false);
  when(() => source.supportFavoriteFolderAdd).thenReturn(false);
  when(() => source.supportFavoriteFolderDelete).thenReturn(false);
  when(() => source.supportFavoriteFolderLoad).thenReturn(false);
  when(() => source.favoriteSortOrder).thenReturn('');
  when(() => source.favoriteSortOrders).thenReturn([]);
  when(
    () => source.cloudFavoritesChangedStream,
  ).thenAnswer((_) => const Stream<void>.empty());
  when(source.ensureInitialized).thenAnswer((_) async {});
  when(() => source.loadFavoriteComics(page: 1, folderId: '0')).thenAnswer(
    (_) async => FavoriteComicsResult.success(
      paginated ? _comics.take(12).toList() : _comics,
      maxPage: paginated ? 2 : 1,
    ),
  );
  when(() => source.loadFavoriteComics(page: 2, folderId: '0')).thenAnswer(
    (_) async =>
        FavoriteComicsResult.success(_comics.skip(12).toList(), maxPage: 2),
  );
  final appearance = _Appearance(layout);
  addTearDown(appearance.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: TargetPlatform.android),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: HazukiThemeControllerScope(
        controller: appearance,
        child: Scaffold(
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
    ),
  );
  if (settle) await tester.pumpAndSettle();
  return source;
}

Future<void> _expectAnimatedEntry(WidgetTester tester, int index) async {
  expect(_progress(tester, index), 0);
  await tester.ensureVisible(_tile(index));
  await tester.pump();
  var sawMotion = false;
  for (var frame = 0; frame < 45; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
    final progress = _progress(tester, index);
    expect(_offset(tester, index).dy, closeTo(0.08 * (1 - progress), 1e-9));
    if (progress > 0 && progress < 1) {
      sawMotion = true;
      break;
    }
  }
  expect(sawMotion, isTrue);
  await tester.pumpAndSettle();
  expect(_progress(tester, index), 1);
}

Future<Map<int, int>> _recordStarts(
  WidgetTester tester,
  List<int> indices,
) async {
  final starts = <int, int>{};
  for (var frame = 0; frame < 100; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
    for (final index in indices) {
      if (_opacity(index).evaluate().isEmpty) continue;
      final progress = _progress(tester, index);
      if (progress > 0) starts.putIfAbsent(index, () => frame);
      expect(_offset(tester, index).dy, closeTo(0.08 * (1 - progress), 1e-9));
    }
    if (starts.length == indices.length) break;
  }
  expect(starts.keys, containsAll(indices));
  for (var i = 1; i < indices.length; i++) {
    expect(
      starts[indices[i]]! - starts[indices[i - 1]]!,
      inInclusiveRange(2, 4),
    );
  }
  return starts;
}

void main() {
  for (final layout in FavoriteLayout.values) {
    testWidgets(
      '$layout staggers entries continuously across the eighth comic',
      (tester) async {
        await _pumpPage(tester, layout, viewportHeight: 2000, settle: false);
        await _recordStarts(tester, List.generate(10, (index) => index));
        await tester.pumpAndSettle();
        expect(_progress(tester, 9), 1);
        expect(_offset(tester, 9), Offset.zero);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('$layout staggers newly visible entries individually', (
      tester,
    ) async {
      await _pumpPage(tester, layout, viewportHeight: 230);
      final rowStart = (16 ~/ layout.columns) * layout.columns;
      expect(_progress(tester, rowStart), 0);
      await tester.ensureVisible(_tile(rowStart));
      await _recordStarts(tester, [rowStart, rowStart + 1]);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('$layout animates comics beyond eight on first visibility', (
      tester,
    ) async {
      await _pumpPage(tester, layout);
      // Waiting past the old 620ms cleanup must not consume offscreen entries.
      await tester.pump(const Duration(seconds: 2));
      await _expectAnimatedEntry(tester, 20);

      await tester.ensureVisible(_tile(0));
      await tester.pumpAndSettle();
      await tester.ensureVisible(_tile(20));
      await tester.pump();
      expect(_progress(tester, 20), 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$layout cancels entries scrolled away while queued', (
      tester,
    ) async {
      await _pumpPage(tester, layout, viewportHeight: 230, settle: false);
      for (
        var frame = 0;
        frame < 10 && _opacity(0).evaluate().isEmpty;
        frame++
      ) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pump();
      final rowStart = (20 ~/ layout.columns) * layout.columns;
      await tester.ensureVisible(_tile(rowStart));
      final starts = await _recordStarts(tester, [rowStart, rowStart + 1]);
      expect(starts[rowStart], lessThanOrEqualTo(4));
      // Returning to a skipped item must still play its entry animation.
      expect(_progress(tester, 1), 0);
      await tester.pumpAndSettle();
      await _expectAnimatedEntry(tester, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'new pages animate on visibility without replaying existing entries',
    (tester) async {
      final source = await _pumpPage(
        tester,
        FavoriteLayout.list,
        paginated: true,
      );
      final scroll = tester
          .widget<ListView>(find.byType(ListView).first)
          .controller!;
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      verify(() => source.loadFavoriteComics(page: 2, folderId: '0')).called(1);
      expect(_progress(tester, 0), 1);
      await _expectAnimatedEntry(tester, 20);
      expect(tester.takeException(), isNull);
    },
  );
}
