import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/app/windows_comic_detail.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/pages/search/search_entry_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    WindowsComicDetailController.instance.close();
  });

  testWidgets('search entry page autofocuses and resizes for keyboard insets', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'search_history': <String>['hazuki'],
    });

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SearchEntryPage(
          comicDetailPageBuilder: _comicDetailPageBuilder,
          comicCoverHeroTagBuilder: (_, {String? salt}) => 'hero-$salt',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    final editableText = tester.widget<EditableText>(find.byType(EditableText));

    expect(scaffold.resizeToAvoidBottomInset, isTrue);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(editableText.focusNode.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
  });
}

Widget _comicDetailPageBuilder(ExploreComic comic, String heroTag) {
  return Scaffold(body: Center(child: Text('detail:${comic.id}-$heroTag')));
}
