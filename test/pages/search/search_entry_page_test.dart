import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/app/windows_comic_detail.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/pages/search/search.dart';
import 'package:hazuki/pages/search/search_entry_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    WindowsComicDetailController.instance.close();
  });

  testWidgets('search entry page applies platform autofocus behavior', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'search_history': <String>['hazuki'],
    });

    await tester.pumpWidget(
      _buildTestApp(
        SearchEntryPage(
          comicDetailPageBuilder: _comicDetailPageBuilder,
          comicCoverHeroTagBuilder: (_, {String? salt}) => 'hero-$salt',
          searchPageLoader: _fakeSearchPageLoader,
        ),
      ),
    );
    await _pumpSearchSettled(tester);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    final editableText = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const ValueKey('search-entry-primary-search-bar')),
        matching: find.byType(EditableText),
      ),
    );

    expect(scaffold.resizeToAvoidBottomInset, isTrue);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    if (Platform.isWindows) {
      expect(editableText.focusNode.hasFocus, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
    } else {
      expect(editableText.focusNode.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
    }
  });

  testWidgets('search entry page single tap restores caret focus', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'search_history': <String>['hazuki'],
    });

    await tester.pumpWidget(
      _buildTestApp(
        SearchEntryPage(
          comicDetailPageBuilder: _comicDetailPageBuilder,
          comicCoverHeroTagBuilder: (_, {String? salt}) => 'hero-$salt',
          searchPageLoader: _fakeSearchPageLoader,
        ),
      ),
    );
    await _pumpSearchSettled(tester);

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey('search-entry-primary-search-bar')),
    );
    await _pumpSearchSettled(tester);

    final editableText = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const ValueKey('search-entry-primary-search-bar')),
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

    await tester.pumpWidget(
      _buildTestApp(
        SearchEntryPage(
          comicDetailPageBuilder: _comicDetailPageBuilder,
          comicCoverHeroTagBuilder: (_, {String? salt}) => 'hero-$salt',
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

  testWidgets(
    'submitting from entry opens results without reopening keyboard',
    (tester) async {
      SharedPreferences.setMockInitialValues(const {});

      await tester.pumpWidget(
        _buildTestApp(
          SearchEntryPage(
            comicDetailPageBuilder: _comicDetailPageBuilder,
            comicCoverHeroTagBuilder: (_, {String? salt}) => 'hero-$salt',
            searchPageLoader: _fakeSearchPageLoader,
          ),
        ),
      );
      await _pumpSearchSettled(tester);

      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('search-entry-primary-search-bar')),
          matching: find.byType(EditableText),
        ),
        'submit-keyword',
      );
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('search-entry-primary-search-bar')),
          matching: find.byIcon(Icons.arrow_forward),
        ),
      );
      await _pumpSearchSettled(tester);

      expect(find.text('Comic submit-keyword 0'), findsOneWidget);
      expect(tester.testTextInput.isVisible, isFalse);
    },
  );

  testWidgets('external keyword opens results without keyboard', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(const {});

    await tester.pumpWidget(
      _buildTestApp(
        SearchPage(
          initialKeyword: 'external-tag',
          comicDetailPageBuilder: _comicDetailPageBuilder,
          comicCoverHeroTagBuilder: (_, {String? salt}) => 'hero-$salt',
          searchPageLoader: _fakeSearchPageLoader,
        ),
      ),
    );
    await _pumpSearchSettled(tester);

    expect(find.text('Comic external-tag 0'), findsOneWidget);
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('collapsed results search can be reopened and submitted', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(const {});
    final requests = <String>[];

    await tester.pumpWidget(
      _buildTestApp(
        SearchPage(
          initialKeyword: 'hazuki',
          comicDetailPageBuilder: _comicDetailPageBuilder,
          comicCoverHeroTagBuilder: (_, {String? salt}) => 'hero-$salt',
          searchPageLoader: _recordingSearchPageLoader(requests),
        ),
      ),
    );
    await _pumpSearchSettled(tester);

    await tester.drag(find.byType(ListView).first, const Offset(0, -420));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('search-results-collapsed-preview')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('search-results-collapsed-preview')),
    );
    await _pumpSearchSettled(tester);

    expect(tester.testTextInput.isVisible, isTrue);

    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('search-results-collapsed-search-bar')),
        matching: find.byType(EditableText),
      ),
      'hazuki-next',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await _pumpSearchSettled(tester);

    expect(requests, contains('hazuki-next'));
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

Widget _comicDetailPageBuilder(ExploreComic comic, String heroTag) {
  return Scaffold(body: Center(child: Text('detail:${comic.id}-$heroTag')));
}
