import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/discover/view/ranking_page.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/shared/windows/windows_comic_detail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/test_service_locator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(const {});
    await ensureTestServiceLocator();
  });

  tearDown(() {
    WindowsComicDetailController.instance.close();
  });

  testWidgets('starts initial ranking load after first build', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RankingPage(
          comicDetailPageBuilder: (_, _) => const SizedBox.shrink(),
        ),
      ),
    );

    expect(find.text('Rankings'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(seconds: 26));
    expect(tester.takeException(), isNull);
  });
}
