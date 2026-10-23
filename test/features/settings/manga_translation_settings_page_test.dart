import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/settings/view/translation/manga_translation_settings_page.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/translation/manga_translation_settings_store.dart';
import 'package:hazuki/services/translation/translation_result_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hazuki/shared/translation/manga_translation_dependencies.dart';
import 'package:hazuki/services/translation/manga_translation_service.dart';
import 'package:hazuki/services/translation/manga_translation_provider_factory.dart';
import 'package:hazuki/services/translation/translation_glossary_store.dart';
import 'package:hazuki/services/translation/translation_response_parser.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hazuki/services/translation/translation_usage_store.dart';

class _Usage extends TranslationUsageStore {
  @override
  Future<Map<String, DailyTranslationUsage>> load() async => {};
}

class _Service extends Mock implements MangaTranslationService {}

class _Cache extends TranslationResultCache {
  @override
  Future<int> sizeBytes() async => 0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MangaTranslationSettingsStore settings;
  late MangaTranslationDependencies dependencies;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    settings = MangaTranslationSettingsStore();
    dependencies = MangaTranslationDependencies(
      settings: settings,
      service: _Service(),
      providers: MangaTranslationProviderFactory(),
      cache: _Cache(),
      glossary: TranslationGlossaryStore(),
      parser: const TranslationResponseParser(),
      usage: _Usage(),
    );
  });
  tearDown(() async {
    settings.dispose();
    dependencies.providers.dispose();
    dependencies.usage.dispose();
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: MangaTranslationSettingsPage(dependencies: dependencies),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'shows controls without app bar blur and switches preset fields',
    (tester) async {
      await settings.updateProvider(
        preset: TranslationProviderPreset.openai,
        baseUrl: 'https://openai.example/v1',
        model: 'openai-model',
        apiKey: 'openai-key',
      );
      await settings.updateProvider(
        preset: TranslationProviderPreset.gemini,
        baseUrl: 'https://gemini.example/openai',
        model: 'gemini-model',
        apiKey: 'gemini-key',
      );
      await pump(tester);
      expect(find.text('Enable manga translation'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text,
        'https://openai.example/v1',
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).at(1)).obscureText,
        isTrue,
      );

      await tester.tap(find.byType(DropdownButton<TranslationProviderPreset>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gemini').last);
      await tester.pumpAndSettle();
      expect(settings.providerPreset, TranslationProviderPreset.gemini);
      expect(
        tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text,
        'https://gemini.example/openai',
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
        'gemini-key',
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).at(2)).controller!.text,
        'gemini-model',
      );
    },
  );

  testWidgets('settings controls fit a narrow viewport', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await settings.load();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: MangaTranslationSettingsPage(dependencies: dependencies),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView), const Offset(0, -450));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('persists editing and explains missing connection configuration', (
    tester,
  ) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField).at(2), 'typed-model');
    await tester.pumpAndSettle();
    expect(settings.model, 'typed-model');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Test connection'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test connection'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Configure the API address, model, and API key in Manga translation settings first',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'thinking effort switches with providers and custom instructions save and reset',
    (tester) async {
      await settings.updateProvider(
        preset: TranslationProviderPreset.openai,
        reasoningEffort: TranslationReasoningEffort.high,
      );
      await settings.updateProvider(
        preset: TranslationProviderPreset.gemini,
        reasoningEffort: TranslationReasoningEffort.low,
      );
      await pump(tester);
      await tester.ensureVisible(
        find.byType(DropdownButton<TranslationReasoningEffort>),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DropdownButton<TranslationReasoningEffort>>(
              find.byType(DropdownButton<TranslationReasoningEffort>),
            )
            .value,
        TranslationReasoningEffort.high,
      );
      await tester.tap(find.byType(DropdownButton<TranslationReasoningEffort>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Medium').last);
      await tester.pumpAndSettle();
      expect(settings.reasoningEffort, TranslationReasoningEffort.medium);
      await tester.ensureVisible(
        find.byType(DropdownButton<TranslationProviderPreset>),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButton<TranslationProviderPreset>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gemini').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byType(DropdownButton<TranslationReasoningEffort>),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DropdownButton<TranslationReasoningEffort>>(
              find.byType(DropdownButton<TranslationReasoningEffort>),
            )
            .value,
        TranslationReasoningEffort.low,
      );
      final promptField = find.byKey(
        const ValueKey('translation-system-prompt'),
      );
      await tester.scrollUntilVisible(
        promptField,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(promptField, 'Preserve honorifics.');
      await tester.pumpAndSettle();
      expect(settings.customSystemPrompt, isEmpty);
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(settings.customSystemPrompt, 'Preserve honorifics.');
      await tester.tap(find.text('Restore default'));
      await tester.pumpAndSettle();
      expect(settings.customSystemPrompt, isEmpty);
      expect(tester.widget<TextField>(promptField).controller!.text, isEmpty);
    },
  );
}
