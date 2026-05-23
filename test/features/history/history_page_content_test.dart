import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/history/view/history_page_content.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/shared/navigation_tags.dart';
import 'package:hazuki/widgets/widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders loading state', (tester) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      _wrapContent(
        scrollController: scrollController,
        loading: true,
        history: const <ExploreComic>[],
      ),
    );

    expect(find.byType(HazukiSandyLoadingIndicator), findsOneWidget);
    expect(find.text('Loading...'), findsOneWidget);
  });

  testWidgets('renders empty state', (tester) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      _wrapContent(
        scrollController: scrollController,
        loading: false,
        history: const <ExploreComic>[],
      ),
    );

    expect(find.text('No history yet'), findsOneWidget);
    expect(find.byType(ListView), findsNothing);
  });

  testWidgets('renders history list and opens comics in normal mode', (
    tester,
  ) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    final openedComicIds = <String>[];
    final openedHeroTags = <String>[];
    final toggledStorageKeys = <String>[];

    await tester.pumpWidget(
      _wrapContent(
        scrollController: scrollController,
        loading: false,
        history: const <ExploreComic>[_comicA, _comicB],
        onOpenComic: (comic, heroTag) async {
          openedComicIds.add(comic.id);
          openedHeroTags.add(heroTag);
        },
        onToggleSelection: (storageKey, {selected}) {
          toggledStorageKeys.add(storageKey);
        },
      ),
    );

    expect(find.text('Comic A'), findsOneWidget);
    expect(find.text('Subtitle A'), findsOneWidget);
    expect(find.text('Comic B'), findsOneWidget);

    await tester.tap(find.text('Comic A'));
    await tester.pump();

    expect(openedComicIds, ['a']);
    expect(openedHeroTags, [comicCoverHeroTag(_comicA, salt: 'history')]);
    expect(toggledStorageKeys, isEmpty);
  });

  testWidgets('selection mode taps toggle selection instead of opening comic', (
    tester,
  ) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    var openCount = 0;
    String? toggledStorageKey;
    bool? toggledSelected;

    await tester.pumpWidget(
      _wrapContent(
        scrollController: scrollController,
        loading: false,
        history: const <ExploreComic>[_comicA],
        selectionMode: true,
        onOpenComic: (comic, heroTag) async {
          openCount++;
        },
        onToggleSelection: (storageKey, {selected}) {
          toggledStorageKey = storageKey;
          toggledSelected = selected;
        },
      ),
    );

    expect(find.byType(Checkbox), findsOneWidget);

    await tester.tap(find.text('Comic A'));
    await tester.pump();

    expect(openCount, 0);
    expect(toggledStorageKey, _comicA.scopedId.storageKey);
    expect(toggledSelected, isNull);
  });

  testWidgets('keeps deleted row briefly so following rows slide up', (
    tester,
  ) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      _wrapContent(
        scrollController: scrollController,
        loading: false,
        history: const <ExploreComic>[_comicA, _comicB, _comicC],
      ),
    );

    expect(find.text('Comic B'), findsOneWidget);
    expect(find.text('Comic C'), findsOneWidget);

    await tester.pumpWidget(
      _wrapContent(
        scrollController: scrollController,
        loading: false,
        history: const <ExploreComic>[_comicA, _comicC],
      ),
    );
    await tester.pump();

    expect(find.text('Comic B'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 260));

    expect(find.text('Comic B'), findsNothing);
    expect(find.text('Comic C'), findsOneWidget);
  });
}

Widget _wrapContent({
  required ScrollController scrollController,
  required bool loading,
  required List<ExploreComic> history,
  bool selectionMode = false,
  Set<String> selectedStorageKeys = const <String>{},
  Future<void> Function(ExploreComic comic, String heroTag)? onOpenComic,
  void Function(String storageKey, {bool? selected})? onToggleSelection,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) {
        final strings = AppLocalizations.of(context)!;
        return Scaffold(
          body: HistoryPageContent(
            loading: loading,
            history: history,
            scrollController: scrollController,
            showBackToTop: false,
            playItemEntryAnimation: false,
            selectionMode: selectionMode,
            selectedStorageKeys: selectedStorageKeys,
            strings: strings,
            comicCoverHeroTagBuilder: comicCoverHeroTag,
            onOpenComic: onOpenComic ?? (_, _) async {},
            onToggleSelection: onToggleSelection ?? (_, {selected}) {},
            onShowMenu: (_, _, _) async {},
            onBackToTopPressed: () async {},
          ),
        );
      },
    ),
  );
}

const _comicA = ExploreComic(
  id: 'a',
  title: 'Comic A',
  subTitle: 'Subtitle A',
  cover: '',
  sourceKey: 'jm',
);

const _comicB = ExploreComic(
  id: 'b',
  title: 'Comic B',
  subTitle: '',
  cover: '',
  sourceKey: 'jm',
);

const _comicC = ExploreComic(
  id: 'c',
  title: 'Comic C',
  subTitle: '',
  cover: '',
  sourceKey: 'jm',
);
