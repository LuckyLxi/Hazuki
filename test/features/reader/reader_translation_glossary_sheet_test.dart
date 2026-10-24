import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/reader/support/reader_translation_controller.dart';
import 'package:hazuki/features/reader/view/reader_translation_actions_sheet.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/translation/detection/translation_detector_model_store.dart';
import 'package:hazuki/services/translation/manga_translation_service.dart';
import 'package:hazuki/services/translation/manga_translation_settings_store.dart';
import 'package:hazuki/services/translation/translation_glossary_store.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Service extends Mock implements MangaTranslationService {
  @override
  Future<void> releaseDetector() async {}
}

/// 内存版术语表，避免在 widget 测试中读写文件。
class _Glossary extends TranslationGlossaryStore {
  final entries = <String, String>{'Alice': '爱丽丝'};

  TranslationGlossaryEntry _entry(String source) => TranslationGlossaryEntry(
    source: source,
    target: entries[source]!,
    addedAt: DateTime(2026),
    lastSeenAt: DateTime(2026),
  );

  @override
  Future<List<TranslationGlossaryEntry>> load(
    String sourceKey,
    String comicId,
  ) async => [for (final source in entries.keys) _entry(source)];

  @override
  Future<void> saveEntry(
    String sourceKey,
    String comicId, {
    required String source,
    required String target,
    String? previousSource,
  }) async {
    entries.remove(previousSource);
    entries[source] = target;
  }

  @override
  Future<void> removeEntry(
    String sourceKey,
    String comicId,
    String source,
  ) async => entries.remove(source);
}

void main() {
  late MangaTranslationSettingsStore settings;
  late TranslationDetectorModelStore models;
  late _Glossary glossary;
  late ReaderTranslationController controller;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    settings = MangaTranslationSettingsStore();
    models = TranslationDetectorModelStore(settings: settings);
    glossary = _Glossary();
    controller = ReaderTranslationController(
      service: _Service(),
      settings: settings,
      models: models,
      glossary: glossary,
      resolveImageBytes: (_) async => Uint8List(0),
      images: () => const [],
      spreadImageIndices: (index) => [index],
      spreadStartIndex: (index) => index,
      spreadSize: () => 1,
      sourceKey: 'source',
      comicId: 'comic',
      onFailure: (_) {},
    );
  });
  tearDown(() {
    controller.dispose();
    models.dispose();
    settings.dispose();
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: ReaderTranslationGlossarySheet(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('edits, adds and deletes glossary terms', (tester) async {
    await pump(tester);
    expect(find.text('Alice → 爱丽丝'), findsOneWidget);

    await tester.tap(find.text('Alice → 爱丽丝'));
    await tester.pumpAndSettle();
    expect(find.text('Edit term'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('glossary-term-target')),
      ' 艾莉丝 ',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(glossary.entries, {'Alice': '艾莉丝'});
    expect(find.text('Alice → 艾莉丝'), findsOneWidget);

    await tester.tap(find.text('Add term'));
    await tester.pumpAndSettle();
    final save = find.widgetWithText(FilledButton, 'Save');
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    await tester.enterText(
      find.byKey(const ValueKey('glossary-term-source')),
      'Bob',
    );
    await tester.enterText(
      find.byKey(const ValueKey('glossary-term-target')),
      '鲍勃',
    );
    await tester.pump();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Bob → 鲍勃'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.widgetWithText(ListTile, 'Alice → 艾莉丝'),
        matching: find.byTooltip('Delete term'),
      ),
    );
    await tester.pumpAndSettle();
    expect(glossary.entries, {'Bob': '鲍勃'});
  });
}
