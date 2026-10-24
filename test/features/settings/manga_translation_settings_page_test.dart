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
import 'package:hazuki/services/translation/detection/translation_detector_model_store.dart';

class _Usage extends TranslationUsageStore {
  @override
  Future<Map<String, DailyTranslationUsage>> load() async => {};
}

class _Service extends Mock implements MangaTranslationService {}

class _Cache extends TranslationResultCache {
  @override
  Future<int> sizeBytes() async => 0;
}

class _Models extends TranslationDetectorModelStore {
  _Models(MangaTranslationSettingsStore settings) : super(settings: settings);

  final states = <String, DetectorModelState>{};
  final downloads = <String>[];

  @override
  Future<void> load() async {}

  @override
  DetectorModelState stateOf(String id) =>
      states[id] ?? const DetectorModelState();

  @override
  Future<void> download(String id) async => downloads.add(id);

  DetectorModelState runtimeValue = const DetectorModelState(
    status: DetectorModelStatus.installed,
  );
  int runtimeDownloads = 0;

  @override
  DetectorModelState get runtimeState => runtimeValue;

  @override
  bool get isRuntimeInstalled =>
      runtimeValue.status == DetectorModelStatus.installed;

  @override
  Future<void> downloadRuntime() async => runtimeDownloads++;

  void set(String id, DetectorModelState state) {
    states[id] = state;
    notifyListeners();
  }

  void setRuntime(DetectorModelState state) {
    runtimeValue = state;
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MangaTranslationSettingsStore settings;
  late _Models models;
  late MangaTranslationDependencies dependencies;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    settings = MangaTranslationSettingsStore();
    models = _Models(settings);
    dependencies = MangaTranslationDependencies(
      settings: settings,
      models: models,
      service: _Service(),
      providers: MangaTranslationProviderFactory(),
      cache: _Cache(),
      glossary: TranslationGlossaryStore(),
      parser: const TranslationResponseParser(),
      usage: _Usage(),
    );
  });
  tearDown(() async {
    models.dispose();
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

  for (final locale in const [Locale('en'), Locale('zh')]) {
    testWidgets('settings controls fit a narrow viewport ($locale)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await settings.load();
      models.set(
        'pp_ocrv5_mobile_det',
        const DetectorModelState(
          status: DetectorModelStatus.downloading,
          progress: 0.4,
          indeterminate: false,
          speedBytesPerSecond: 1200000,
        ),
      );
      models.set(
        'pp_ocrv5_server_det',
        const DetectorModelState(
          status: DetectorModelStatus.failed,
          failure: DetectorModelFailure.checksumMismatch,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: locale,
          home: MangaTranslationSettingsPage(dependencies: dependencies),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
      for (var index = 0; index < 4; index++) {
        await tester.drag(find.byType(ListView), const Offset(0, -450));
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('detector models download, select and hide for AI locating', (
    tester,
  ) async {
    await pump(tester);
    final required = find.text('Download and select a detection model');
    await tester.scrollUntilVisible(
      required,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(required, findsOneWidget);
    expect(find.text('95 MB · GPL-3.0'), findsOneWidget);

    final ctd = find.byKey(
      const ValueKey('translation-detector-comic_text_detector'),
    );
    final download = find.descendant(of: ctd, matching: find.text('Download'));
    await tester.ensureVisible(download);
    await tester.pumpAndSettle();
    await tester.tap(download);
    expect(models.downloads, ['comic_text_detector']);

    models.set(
      'comic_text_detector',
      const DetectorModelState(
        status: DetectorModelStatus.downloading,
        progress: 0.5,
        indeterminate: false,
        speedBytesPerSecond: 2000000,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('50% · 2.0 MB/s'), findsOneWidget);

    models.set(
      'comic_text_detector',
      const DetectorModelState(status: DetectorModelStatus.installed),
    );
    await tester.pumpAndSettle();
    expect(settings.detectorModelId, isNull);
    final use = find.descendant(of: ctd, matching: find.text('Use'));
    await tester.ensureVisible(use);
    await tester.pumpAndSettle();
    await tester.tap(use);
    await tester.pumpAndSettle();
    expect(settings.detectorModelId, 'comic_text_detector');
    expect(required, findsNothing);
    expect(find.descendant(of: ctd, matching: find.text('Use')), findsNothing);

    await tester.ensureVisible(find.text('AI'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AI'));
    await tester.pumpAndSettle();
    expect(settings.textLocator, TranslationTextLocator.ai);
    expect(ctd, findsNothing);
  });

  testWidgets('the runtime row gates model selection', (tester) async {
    models.setRuntime(const DetectorModelState());
    models.set(
      'pp_ocrv5_mobile_det',
      const DetectorModelState(status: DetectorModelStatus.installed),
    );
    await pump(tester);
    final runtimeRequired = find.text('Download the detection runtime first');
    await tester.scrollUntilVisible(
      runtimeRequired,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(runtimeRequired, findsOneWidget);
    expect(find.text('Download and select a detection model'), findsNothing);
    final runtimeRow = find.byKey(
      const ValueKey('translation-detector-runtime'),
    );
    expect(
      find.descendant(
        of: runtimeRow,
        matching: find.text('ONNX Runtime 1.23.2'),
      ),
      findsOneWidget,
    );
    final mobile = find.byKey(
      const ValueKey('translation-detector-pp_ocrv5_mobile_det'),
    );
    final use = find.descendant(
      of: mobile,
      matching: find.widgetWithText(FilledButton, 'Use'),
    );
    await tester.ensureVisible(use);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(use).onPressed, isNull);

    final download = find.descendant(
      of: runtimeRow,
      matching: find.text('Download'),
    );
    await tester.ensureVisible(download);
    await tester.pumpAndSettle();
    await tester.tap(download);
    expect(models.runtimeDownloads, 1);

    models.setRuntime(
      const DetectorModelState(status: DetectorModelStatus.installed),
    );
    await tester.pumpAndSettle();
    expect(runtimeRequired, findsNothing);
    expect(find.text('Download and select a detection model'), findsOneWidget);
    expect(tester.widget<FilledButton>(use).onPressed, isNotNull);
  });

  testWidgets('shows a changed model source as a distinct failure', (
    tester,
  ) async {
    models.set(
      'pp_ocrv5_server_det',
      const DetectorModelState(
        status: DetectorModelStatus.failed,
        failure: DetectorModelFailure.checksumMismatch,
      ),
    );
    await pump(tester);
    final message = find.text(
      "The model source file has changed, so this model can't be used for now",
    );
    await tester.scrollUntilVisible(
      message,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(message, findsOneWidget);
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
