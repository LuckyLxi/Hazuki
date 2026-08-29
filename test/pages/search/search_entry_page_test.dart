import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/app/service_locator.dart';
import 'package:hazuki/app/app.dart';
import 'package:hazuki/shared/windows/windows_comic_detail.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/features/search/search.dart';
import 'package:hazuki/features/search/view/search_entry_page.dart';
import 'package:hazuki/features/search/view/search_entry_widgets.dart';
import 'package:hazuki/features/search/view/search_id_extract_pill.dart';
import 'package:hazuki/services/search_history_service.dart';
import 'package:hazuki/services/source/runtime/source_runtime_assembly.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/shared/search_box_outline.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../support/test_service_locator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    await ensureTestServiceLocator();
  });

  tearDown(() {
    WindowsComicDetailController.instance.close();
  });

  testWidgets('search entry page does not autofocus on entry', (tester) async {
    SharedPreferences.setMockInitialValues({
      'search_history': <String>['hazuki'],
    });
    await sl<SearchHistoryService>().load();

    await tester.pumpWidget(
      _buildTestApp(
        SearchEntryPage(
          sourceService: sl<SourceSearchGateway>(),
          historyService: sl<SearchHistoryService>(),
          comicDetailPageBuilder: _comicDetailPageBuilder,
          comicCoverHeroTagBuilder: _testComicCoverHeroTag,
          searchPageLoader: _fakeSearchPageLoader,
        ),
      ),
    );
    await _pumpSearchSettled(tester);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    final editableText = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const ValueKey('search-entry-app-bar-search-bar')),
        matching: find.byType(EditableText),
      ),
    );

    expect(scaffold.resizeToAvoidBottomInset, isTrue);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(editableText.focusNode.hasFocus, isFalse);
    expect(tester.testTextInput.isVisible, isFalse);

    expect(
      find.ancestor(
        of: find.byType(SearchEntryBody),
        matching: find.byType(SnapshotWidget),
      ),
      findsNothing,
    );
    expect(
      find.ancestor(
        of: find.byType(SearchEntryBody),
        matching: find.byType(RepaintBoundary),
      ),
      findsWidgets,
    );
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('search-entry-app-bar-search-bar')),
        matching: find.byType(SnapshotWidget),
      ),
      findsNothing,
    );
    expect(
      find.ancestor(
        of: find.byType(FloatingActionButton),
        matching: find.byType(SnapshotWidget),
      ),
      findsNothing,
    );
  });

  testWidgets('history FAB keeps its safe-area margin as keyboard closes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'search_history': <String>['hazuki'],
    });
    await sl<SearchHistoryService>().load();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) {
          final mediaQuery = MediaQuery.of(context);
          return MediaQuery(
            data: mediaQuery.copyWith(
              viewInsets: const EdgeInsets.only(bottom: 1),
              viewPadding: const EdgeInsets.only(bottom: 24),
            ),
            child: child!,
          );
        },
        home: SearchEntryPage(
          sourceService: sl<SourceSearchGateway>(),
          historyService: sl<SearchHistoryService>(),
          comicDetailPageBuilder: _comicDetailPageBuilder,
          comicCoverHeroTagBuilder: _testComicCoverHeroTag,
          searchPageLoader: _fakeSearchPageLoader,
        ),
      ),
    );
    await _pumpSearchSettled(tester);

    final scaffoldRect = tester.getRect(find.byType(Scaffold).first);
    final fabRect = tester.getRect(find.byType(FloatingActionButton));

    expect(
      fabRect.bottom,
      lessThanOrEqualTo(scaffoldRect.bottom - 24 - kFloatingActionButtonMargin),
    );
  });

  testWidgets('back starts popping while locking the keyboard layout', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(const {});

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  Navigator.of(context).push<void>(
                    buildSearchEntryPageRoute<void>(
                      builder: (_) => SearchEntryPage(
                        sourceService: sl<SourceSearchGateway>(),
                        historyService: sl<SearchHistoryService>(),
                        comicDetailPageBuilder: _comicDetailPageBuilder,
                        comicCoverHeroTagBuilder: _testComicCoverHeroTag,
                        searchPageLoader: _fakeSearchPageLoader,
                      ),
                    ),
                  );
                },
                child: const Text('Open search'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open search'));
    await _pumpSearchSettled(tester);
    await tester.tap(
      find.byKey(const ValueKey('search-entry-app-bar-search-bar')),
    );
    await _pumpSearchSettled(tester);

    expect(tester.testTextInput.isVisible, isTrue);
    expect(find.byType(SearchEntryPage), findsOneWidget);
    final route = ModalRoute.of(tester.element(find.byType(SearchEntryPage)))!;

    await tester.tap(find.byType(BackButton));
    await tester.pump();

    expect(tester.testTextInput.isVisible, isFalse);
    expect(route.animation!.status, AnimationStatus.reverse);

    await tester.pumpAndSettle();

    expect(find.byType(SearchEntryPage), findsNothing);
    expect(find.text('Open search'), findsOneWidget);
  });

  testWidgets('history loads before the search entry transition completes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(const {});
    await sl<SearchHistoryService>().replace(const ['early-history']);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () {
              Navigator.of(context).push<void>(
                buildSearchEntryPageRoute<void>(
                  builder: (_) => SearchEntryPage(
                    sourceService: sl<SourceSearchGateway>(),
                    historyService: sl<SearchHistoryService>(),
                    comicDetailPageBuilder: _comicDetailPageBuilder,
                    comicCoverHeroTagBuilder: _testComicCoverHeroTag,
                    searchPageLoader: _fakeSearchPageLoader,
                  ),
                ),
              );
            },
            child: const Text('Open search'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open search'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final route = ModalRoute.of(tester.element(find.byType(SearchEntryPage)))!;
    expect(route.animation!.status, AnimationStatus.forward);
    expect(find.text('early-history'), findsOneWidget);
  });

  testWidgets(
    'prepared autofocus entry shows the keyboard when the transition completes',
    (tester) async {
      SharedPreferences.setMockInitialValues(const {});
      final historyService = sl<SearchHistoryService>();
      await historyService.replace(const ['prepared-history']);
      await historyService.load();

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                Navigator.of(context).push<void>(
                  buildSearchEntryPageRoute<void>(
                    builder: (_) => SearchEntryPage(
                      sourceService: sl<SourceSearchGateway>(),
                      historyService: historyService,
                      autoFocusOnOpen: true,
                      comicDetailPageBuilder: _comicDetailPageBuilder,
                      comicCoverHeroTagBuilder: _testComicCoverHeroTag,
                      searchPageLoader: _fakeSearchPageLoader,
                    ),
                  ),
                );
              },
              child: const Text('Open prepared search'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open prepared search'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));

      final searchBarFinder = find.byKey(
        const ValueKey('search-entry-app-bar-search-bar'),
      );
      final searchBar = tester.widget<SearchBar>(
        find.descendant(of: searchBarFinder, matching: find.byType(SearchBar)),
      );
      final searchBarContext = tester.element(searchBarFinder);
      final route = ModalRoute.of(
        tester.element(find.byType(SearchEntryPage)),
      )!;

      expect(route.animation!.status, AnimationStatus.forward);
      expect(find.text('prepared-history'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(
        searchBar.backgroundColor!.resolve(const <WidgetState>{}),
        hazukiSearchBoxBackgroundColor(searchBarContext, focusProgress: 1),
      );

      await tester.pump(const Duration(milliseconds: 350));
      expect(route.animation!.status, AnimationStatus.forward);
      expect(tester.testTextInput.isVisible, isFalse);

      await tester.pump(const Duration(milliseconds: 30));
      expect(route.animation!.status, AnimationStatus.forward);
      expect(tester.testTextInput.isVisible, isFalse);

      await tester.pump(const Duration(milliseconds: 120));
      expect(route.animation!.status, AnimationStatus.completed);
      expect(tester.testTextInput.isVisible, isTrue);
    },
  );

  testWidgets('search settings toggles and persists aggregate search', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      hazukiAggregateSearchEnabledPreferenceKey: false,
    });

    await tester.pumpWidget(
      _buildTestApp(
        SearchEntryPage(
          sourceService: sl<SourceSearchGateway>(),
          historyService: sl<SearchHistoryService>(),
          comicDetailPageBuilder: _comicDetailPageBuilder,
          comicCoverHeroTagBuilder: _testComicCoverHeroTag,
          searchPageLoader: _fakeSearchPageLoader,
        ),
      ),
    );
    await _pumpSearchSettled(tester);

    await tester.tap(find.byKey(const ValueKey('search-settings-button')));
    await tester.pumpAndSettle();

    final switchFinder = find.byKey(const ValueKey('aggregate-search-switch'));
    expect(switchFinder, findsOneWidget);
    expect(tester.widget<SwitchListTile>(switchFinder).value, isFalse);

    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    expect(tester.widget<SwitchListTile>(switchFinder).value, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(hazukiAggregateSearchEnabledPreferenceKey), isTrue);
  });

  testWidgets('search entry page refreshes after external history changes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(const {});

    await tester.pumpWidget(
      _buildTestApp(
        SearchEntryPage(
          sourceService: sl<SourceSearchGateway>(),
          historyService: sl<SearchHistoryService>(),
          comicDetailPageBuilder: _comicDetailPageBuilder,
          comicCoverHeroTagBuilder: _testComicCoverHeroTag,
          searchPageLoader: _fakeSearchPageLoader,
        ),
      ),
    );
    await _pumpSearchSettled(tester);
    expect(find.text('synced-keyword'), findsNothing);

    await sl<SearchHistoryService>().replace(['synced-keyword']);
    await _pumpSearchSettled(tester);

    expect(find.text('synced-keyword'), findsOneWidget);
  });

  testWidgets('search entry page single tap restores caret focus', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'search_history': <String>['hazuki'],
    });
    await sl<SearchHistoryService>().load();

    await tester.pumpWidget(
      _buildTestApp(
        SearchEntryPage(
          sourceService: sl<SourceSearchGateway>(),
          historyService: sl<SearchHistoryService>(),
          comicDetailPageBuilder: _comicDetailPageBuilder,
          comicCoverHeroTagBuilder: _testComicCoverHeroTag,
          searchPageLoader: _fakeSearchPageLoader,
        ),
      ),
    );
    await _pumpSearchSettled(tester);

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey('search-entry-app-bar-search-bar')),
    );
    await _pumpSearchSettled(tester);

    final editableText = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const ValueKey('search-entry-app-bar-search-bar')),
        matching: find.byType(EditableText),
      ),
    );

    expect(editableText.focusNode.hasFocus, isTrue);
    expect(editableText.controller.selection.isValid, isTrue);
    expect(
      editableText.controller.selection.baseOffset,
      editableText.controller.text.length,
    );
  });

  testWidgets('history selection opens results without showing keyboard', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'search_history': <String>['hazuki'],
    });
    await sl<SearchHistoryService>().load();

    await tester.pumpWidget(
      _buildTestApp(
        SearchEntryPage(
          sourceService: sl<SourceSearchGateway>(),
          historyService: sl<SearchHistoryService>(),
          comicDetailPageBuilder: _comicDetailPageBuilder,
          comicCoverHeroTagBuilder: _testComicCoverHeroTag,
          searchPageLoader: _fakeSearchPageLoader,
        ),
      ),
    );
    await _pumpSearchSettled(tester);

    await tester.tap(find.text('hazuki'));
    await _pumpSearchSettled(tester);

    expect(find.text('Comic hazuki 0'), findsOneWidget);
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('long pressing a search history keyword copies it', (
    tester,
  ) async {
    String? copiedText;
    String? hapticType;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedText =
              (call.arguments as Map<dynamic, dynamic>)['text'] as String?;
        } else if (call.method == 'HapticFeedback.vibrate') {
          hapticType = call.arguments as String?;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
    SharedPreferences.setMockInitialValues({
      'search_history': <String>['hazuki'],
    });
    await sl<SearchHistoryService>().load();

    await tester.pumpWidget(
      _buildTestApp(
        SearchEntryPage(
          sourceService: sl<SourceSearchGateway>(),
          historyService: sl<SearchHistoryService>(),
          comicDetailPageBuilder: _comicDetailPageBuilder,
          comicCoverHeroTagBuilder: _testComicCoverHeroTag,
          searchPageLoader: _fakeSearchPageLoader,
        ),
      ),
    );
    await _pumpSearchSettled(tester);

    await tester.longPress(find.text('hazuki'));
    await _pumpSearchSettled(tester);

    expect(copiedText, 'hazuki');
    expect(hapticType, 'HapticFeedbackType.mediumImpact');
    expect(find.text('Search history copied'), findsOneWidget);
    expect(find.text('Comic hazuki 0'), findsNothing);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'submitting from entry opens results without reopening keyboard',
    (tester) async {
      SharedPreferences.setMockInitialValues(const {});

      await tester.pumpWidget(
        _buildTestApp(
          SearchEntryPage(
            sourceService: sl<SourceSearchGateway>(),
            historyService: sl<SearchHistoryService>(),
            comicDetailPageBuilder: _comicDetailPageBuilder,
            comicCoverHeroTagBuilder: _testComicCoverHeroTag,
            searchPageLoader: _fakeSearchPageLoader,
          ),
        ),
      );
      await _pumpSearchSettled(tester);

      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('search-entry-app-bar-search-bar')),
          matching: find.byType(EditableText),
        ),
        'submit-keyword',
      );
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('search-entry-app-bar-search-bar')),
          matching: find.byIcon(Icons.arrow_forward),
        ),
      );
      await _pumpSearchSettled(tester);

      expect(find.text('Comic submit-keyword 0'), findsOneWidget);
      expect(tester.testTextInput.isVisible, isFalse);
    },
  );

  testWidgets('comic id enhancement does not rewrite keyboard submissions', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      hazukiComicIdSearchEnhancePreferenceKey: true,
    });
    final requests = <String>[];

    await tester.pumpWidget(
      _buildTestApp(
        SearchEntryPage(
          sourceService: sl<SourceSearchGateway>(),
          historyService: sl<SearchHistoryService>(),
          comicDetailPageBuilder: _comicDetailPageBuilder,
          comicCoverHeroTagBuilder: _testComicCoverHeroTag,
          searchPageLoader: _recordingSearchPageLoader(requests),
        ),
      ),
    );
    await _pumpSearchSettled(tester);

    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('search-entry-app-bar-search-bar')),
        matching: find.byType(EditableText),
      ),
      'abc123def',
    );
    await tester.pump();

    expect(_currentExtractedId(tester), '123');

    await tester.testTextInput.receiveAction(TextInputAction.search);
    await _pumpSearchSettled(tester);

    expect(requests, contains('abc123def'));
    expect(requests, isNot(contains('123')));
    expect(_currentExtractedId(tester), isNull);

    await tester.tap(
      find.byKey(const ValueKey('search-results-app-bar-search-bar')),
    );
    await tester.pump();

    expect(_currentExtractedId(tester), '123');

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 100));

    expect(_currentExtractedId(tester), '123');

    await tester.pump(const Duration(milliseconds: 250));

    expect(_currentExtractedId(tester), isNull);
  });

  testWidgets('comic id pill applies the extracted id', (tester) async {
    SharedPreferences.setMockInitialValues({
      hazukiComicIdSearchEnhancePreferenceKey: true,
    });
    final requests = <String>[];

    await tester.pumpWidget(
      _buildTestApp(
        SearchEntryPage(
          sourceService: sl<SourceSearchGateway>(),
          historyService: sl<SearchHistoryService>(),
          comicDetailPageBuilder: _comicDetailPageBuilder,
          comicCoverHeroTagBuilder: _testComicCoverHeroTag,
          searchPageLoader: _recordingSearchPageLoader(requests),
        ),
      ),
    );
    await _pumpSearchSettled(tester);

    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('search-entry-app-bar-search-bar')),
        matching: find.byType(EditableText),
      ),
      'abc123def',
    );
    await tester.pumpAndSettle();

    expect(_currentExtractedId(tester), '123');

    await tester.tap(find.text('Extracted: 123'));
    await _pumpSearchSettled(tester);

    expect(requests, contains('123'));
    expect(requests, isNot(contains('abc123def')));
  });

  testWidgets('results comic id pill dismisses the keyboard', (tester) async {
    SharedPreferences.setMockInitialValues({
      hazukiComicIdSearchEnhancePreferenceKey: true,
    });
    final requests = <String>[];

    await tester.pumpWidget(
      _buildTestApp(
        SearchPage(
          sourceService: sl<SourceSearchGateway>(),
          historyService: sl<SearchHistoryService>(),
          initialKeyword: 'hazuki',
          comicDetailPageBuilder: _comicDetailPageBuilder,
          comicCoverHeroTagBuilder: _testComicCoverHeroTag,
          searchPageLoader: _recordingSearchPageLoader(requests),
        ),
      ),
    );
    await _pumpSearchSettled(tester);

    final resultsSearch = find.byKey(
      const ValueKey('search-results-app-bar-search-bar'),
    );
    await tester.tap(resultsSearch);
    await tester.enterText(
      find.descendant(of: resultsSearch, matching: find.byType(EditableText)),
      'abc123def',
    );
    await tester.pumpAndSettle();

    expect(_currentExtractedId(tester), '123');
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.tap(find.text('Extracted: 123'));
    await _pumpSearchSettled(tester);

    expect(requests, contains('123'));
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('comic id enhancement is inactive on non-JM sources', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      hazukiComicIdSearchEnhancePreferenceKey: true,
    });
    await sl<SourceRuntimeAssembly>().runtimeRegistry.activateSource(
      'copy_manga',
    );

    await tester.pumpWidget(
      _buildTestApp(
        SearchEntryPage(
          sourceService: sl<SourceSearchGateway>(),
          historyService: sl<SearchHistoryService>(),
          comicDetailPageBuilder: _comicDetailPageBuilder,
          comicCoverHeroTagBuilder: _testComicCoverHeroTag,
          searchPageLoader: _fakeSearchPageLoader,
        ),
      ),
    );
    await _pumpSearchSettled(tester);

    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('search-entry-app-bar-search-bar')),
        matching: find.byType(EditableText),
      ),
      'abc123def',
    );
    await tester.pump();

    expect(_currentExtractedId(tester), isNull);
  });

  testWidgets('external keyword opens results without keyboard', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(const {});

    await tester.pumpWidget(
      _buildTestApp(
        SearchPage(
          sourceService: sl<SourceSearchGateway>(),
          historyService: sl<SearchHistoryService>(),
          initialKeyword: 'external-tag',
          comicDetailPageBuilder: _comicDetailPageBuilder,
          comicCoverHeroTagBuilder: _testComicCoverHeroTag,
          searchPageLoader: _fakeSearchPageLoader,
        ),
      ),
    );
    await _pumpSearchSettled(tester);

    expect(find.text('Comic external-tag 0'), findsOneWidget);
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('results clear button only clears the search field', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(const {});

    await tester.pumpWidget(
      _buildTestApp(
        SearchPage(
          sourceService: sl<SourceSearchGateway>(),
          historyService: sl<SearchHistoryService>(),
          initialKeyword: 'keep-results',
          comicDetailPageBuilder: _comicDetailPageBuilder,
          comicCoverHeroTagBuilder: _testComicCoverHeroTag,
          searchPageLoader: _fakeSearchPageLoader,
        ),
      ),
    );
    await _pumpSearchSettled(tester);

    expect(find.text('Comic keep-results 0'), findsOneWidget);
    final resultsSearch = find.byKey(
      const ValueKey('search-results-app-bar-search-bar'),
    );
    await tester.tap(
      find.descendant(of: resultsSearch, matching: find.byIcon(Icons.close)),
    );
    await _pumpSearchSettled(tester);

    final editableText = tester.widget<EditableText>(
      find.descendant(of: resultsSearch, matching: find.byType(EditableText)),
    );
    expect(editableText.controller.text, isEmpty);
    expect(find.text('Comic keep-results 0'), findsOneWidget);
  });

  testWidgets('aggregate JM id lookup shows loading before opening detail', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(const {});
    final detailsCompleter = Completer<ComicDetailsData>();
    String? requestedSourceKey;

    await tester.pumpWidget(
      _buildTestApp(
        SearchResultsPage(
          sourceService: sl<SourceSearchGateway>(),
          historyService: sl<SearchHistoryService>(),
          initialKeyword: '12345',
          aggregateSearchEnabled: true,
          comicDetailPageBuilder: _comicDetailPageBuilder,
          comicCoverHeroTagBuilder: _testComicCoverHeroTag,
          comicDetailsLoader: (comicId, {required sourceKey}) {
            requestedSourceKey = sourceKey;
            return detailsCompleter.future;
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(requestedSourceKey, jmSearchSourceKey);
    expect(find.byKey(const ValueKey('search-loading')), findsOneWidget);
    expect(find.byKey(const ValueKey('empty')), findsNothing);

    detailsCompleter.complete(
      const ComicDetailsData(
        id: '12345',
        title: 'JM 12345',
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
        sourceKey: jmSearchSourceKey,
      ),
    );
    await _pumpSearchSettled(tester);

    if (useWindowsComicDetailPanel) {
      expect(WindowsComicDetailController.instance.entry?.comic.id, '12345');
    } else {
      expect(find.textContaining('detail:12345-'), findsOneWidget);
    }
  });

  testWidgets('results search loses focus on outside interactions', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(const {});

    await tester.pumpWidget(
      _buildTestApp(
        SearchPage(
          sourceService: sl<SourceSearchGateway>(),
          historyService: sl<SearchHistoryService>(),
          initialKeyword: 'hazuki',
          comicDetailPageBuilder: _comicDetailPageBuilder,
          comicCoverHeroTagBuilder: _testComicCoverHeroTag,
          searchPageLoader: _fakeSearchPageLoader,
        ),
      ),
    );
    await _pumpSearchSettled(tester);

    final resultsSearch = find.byKey(
      const ValueKey('search-results-app-bar-search-bar'),
    );

    await tester.tap(resultsSearch);
    await _pumpSearchSettled(tester);

    var editableText = tester.widget<EditableText>(
      find.descendant(of: resultsSearch, matching: find.byType(EditableText)),
    );
    expect(editableText.focusNode.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();

    editableText = tester.widget<EditableText>(
      find.descendant(of: resultsSearch, matching: find.byType(EditableText)),
    );
    expect(editableText.focusNode.hasFocus, isFalse);
    expect(tester.testTextInput.isVisible, isFalse);

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();

    await tester.tap(resultsSearch);
    await _pumpSearchSettled(tester);

    editableText = tester.widget<EditableText>(
      find.descendant(of: resultsSearch, matching: find.byType(EditableText)),
    );
    expect(editableText.focusNode.hasFocus, isTrue);

    await tester.drag(find.byType(ListView).first, const Offset(0, -160));
    await _pumpSearchSettled(tester);

    editableText = tester.widget<EditableText>(
      find.descendant(of: resultsSearch, matching: find.byType(EditableText)),
    );
    expect(editableText.focusNode.hasFocus, isFalse);
    expect(tester.testTextInput.isVisible, isFalse);

    await tester.tap(resultsSearch);
    await _pumpSearchSettled(tester);

    await tester.tap(find.text('Comic hazuki 3'));
    await _pumpSearchSettled(tester);

    if (useWindowsComicDetailPanel) {
      expect(
        WindowsComicDetailController.instance.entry?.comic.id,
        'hazuki-1-3',
      );
    } else {
      expect(
        find.text('detail:hazuki-1-3-hero-search-results-hazuki-1-3'),
        findsOneWidget,
      );
    }
    expect(tester.testTextInput.isVisible, isFalse);
  });
}

Widget _buildTestApp(Widget home) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}

String _testComicCoverHeroTag(ExploreComic comic, {String? salt}) {
  return 'hero-${salt ?? 'search'}-${comic.id}';
}

Future<void> _pumpSearchSettled(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

Future<SearchComicsResult> _fakeSearchPageLoader(
  BuildContext context, {
  required String keyword,
  required int page,
  required String order,
}) async {
  return SearchComicsResult(
    comics: List<ExploreComic>.generate(
      20,
      (index) => ExploreComic(
        id: '$keyword-$page-$index',
        title: 'Comic $keyword $index',
        subTitle: 'Order $order',
        cover: '',
      ),
    ),
    maxPage: 2,
  );
}

SearchPageLoader _recordingSearchPageLoader(List<String> requests) {
  return (
    BuildContext context, {
    required String keyword,
    required int page,
    required String order,
  }) {
    requests.add(keyword);
    return _fakeSearchPageLoader(
      context,
      keyword: keyword,
      page: page,
      order: order,
    );
  };
}

String? _currentExtractedId(WidgetTester tester) {
  final pills = tester.widgetList<SearchIdExtractPill>(
    find.byType(SearchIdExtractPill),
  );
  expect(pills, isNotEmpty);
  return pills.last.extractedId;
}

Widget _comicDetailPageBuilder(ExploreComic comic, String heroTag) {
  return Scaffold(body: Center(child: Text('detail:${comic.id}-$heroTag')));
}
