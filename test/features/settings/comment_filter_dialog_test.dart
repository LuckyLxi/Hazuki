import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/app/service_locator.dart';
import 'package:hazuki/features/settings/view/other/comment_filter_dialog.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/comment_filter_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const multilineKeyword =
      '給大家發個蘿莉視頻破.解版，幼和禁區.視頻豐富，都不收費已經去廣告！拿走不用謝！！\n'
      '下栽鏈.接在我頭.像，輸入到瀏覽器就可以打開了';

  setUp(() async {
    await sl.reset();
    SharedPreferences.setMockInitialValues(const {});
    final service = CommentFilterService();
    await service.load();
    sl.registerSingleton<CommentFilterService>(service);
  });

  tearDown(() async {
    await sl.reset();
  });

  testWidgets('save includes a keyword still present in the input field', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showCommentFilterDialog(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'blocked phrase');

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(sl<CommentFilterService>().userKeywords, ['blocked phrase']);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('comment_filter_keywords'), ['blocked phrase']);
  });

  testWidgets('sheet meets the keyboard and keeps save visible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const keyboardHeight = 280.0;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) {
          final mediaQuery = MediaQuery.of(context);
          return MediaQuery(
            data: mediaQuery.copyWith(
              viewInsets: const EdgeInsets.only(bottom: keyboardHeight),
            ),
            child: child!,
          );
        },
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showCommentFilterDialog(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final saveButtonRect = tester.getRect(
      find.byKey(const ValueKey<String>('comment-filter-save-button')),
    );
    final sheetRect = tester.getRect(
      find.byKey(const ValueKey<String>('comment-filter-sheet')),
    );
    final keyboardTop = tester.view.physicalSize.height - keyboardHeight;

    expect(sheetRect.bottom, keyboardTop);
    expect(saveButtonRect.bottom, lessThanOrEqualTo(keyboardTop - 8));
  });

  testWidgets('add accepts a long pasted keyword after stripping its newline', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showCommentFilterDialog(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), multilineKeyword);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(sl<CommentFilterService>().userKeywords, [
      multilineKeyword.replaceAll('\n', ''),
    ]);
  });
}
