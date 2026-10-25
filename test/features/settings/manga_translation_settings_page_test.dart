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
import 'package:hazuki/services/translation/translation_glossary_store.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hazuki/services/translation/translation_usage_store.dart';
import 'package:hazuki/services/translation/detection/translation_detector_model_store.dart';
import 'package:hazuki/widgets/hazuki_frosted_menu_button.dart';

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
      cache: _Cache(),
      glossary: TranslationGlossaryStore(),
      usage: _Usage(),
    );
  });
  tearDown(() async {
    models.dispose();
    settings.dispose();
    dependencies.usage.dispose();
  });

  Future<void> pump(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        home: MangaTranslationSettingsPage(dependencies: dependencies),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester, Finder entry) async {
    await tester.scrollUntilVisible(
      entry,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(entry);
    await tester.pumpAndSettle();
  }

  Future<void> openProvider(WidgetTester tester) =>
      open(tester, find.text('Provider & model'));

  Future<void> openLocator(WidgetTester tester) =>
      open(tester, find.byKey(const ValueKey('translation-locator-entry')));

  testWidgets('home summarizes status and toggles translation', (tester) async {
    await pump(tester);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.text('Translation is off'), findsOneWidget);
    expect(find.text('Provider not configured'), findsOneWidget);
    expect(find.text('On-device detection not ready'), findsOneWidget);
    expect(find.text('On-device · No model selected'), findsOneWidget);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(settings.enabled, isTrue);
    expect(find.text('Translation is on'), findsOneWidget);
  });

  testWidgets('home adjusts reading options in place', (tester) async {
    await pump(tester);
    final three = find.byKey(const ValueKey('translation-prefetch-3'));
    await tester.scrollUntilVisible(
      three,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(three);
    await tester.pumpAndSettle();
    expect(settings.prefetchAhead, 3);
    expect(find.text('Next 3 pages'), findsOneWidget);

    final white = find.byKey(const ValueKey('translation-bubble-white'));
    await tester.ensureVisible(white);
    await tester.pumpAndSettle();
    await tester.tap(white);
    await tester.pumpAndSettle();
    expect(settings.bubbleStyle, TranslationBubbleStyle.white);

    await tester.ensureVisible(find.text('Target language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Target language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('日本語'));
    await tester.pumpAndSettle();
    expect(settings.targetLanguage, TranslationTargetLanguage.japanese);
  });

  testWidgets('target language dialog animates opening and dismissal', (
    tester,
  ) async {
    await pump(tester);
    final originalLanguage = settings.targetLanguage;
    final entry = find.text('Target language');
    await tester.scrollUntilVisible(
      entry,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(entry);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    final dialog = find.byType(SimpleDialog);
    double height() =>
        tester.getBottomRight(dialog).dy - tester.getTopLeft(dialog).dy;
    final openingHeight = height();
    await tester.pumpAndSettle();
    final fullHeight = height();
    expect(openingHeight, lessThan(fullHeight));

    await tester.tapAt(const Offset(8, 8));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(dialog, findsOneWidget);
    expect(height(), lessThan(fullHeight));
    await tester.pumpAndSettle();
    expect(dialog, findsNothing);
    expect(settings.targetLanguage, originalLanguage);
  });

  testWidgets('provider page switches preset fields', (tester) async {
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
    expect(find.text('OpenAI · openai-model'), findsOneWidget);
    await openProvider(tester);
    expect(
      tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text,
      'https://openai.example/v1',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).at(1)).obscureText,
      isTrue,
    );

    await tester.tap(
      find.byType(HazukiMenuSettingTile<TranslationProviderPreset>),
    );
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
  });

  for (final locale in const [Locale('en'), Locale('zh')]) {
    testWidgets('pages fit a narrow viewport ($locale)', (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
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
      await pump(tester, locale: locale);
      expect(tester.takeException(), isNull);
      for (var index = 0; index < 4; index++) {
        await tester.drag(find.byType(ListView), const Offset(0, -450));
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
      await tester.drag(find.byType(ListView), const Offset(0, 3000));
      await tester.pumpAndSettle();
      await openLocator(tester);
      expect(tester.takeException(), isNull);
      for (var index = 0; index < 4; index++) {
        await tester.drag(find.byType(ListView).last, const Offset(0, -450));
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('detector models download, select and hide for AI locating', (
    tester,
  ) async {
    await pump(tester);
    await openLocator(tester);
    final required = find.text('Download and select a detection model');
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
    await tester.ensureVisible(ctd);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: ctd, matching: find.text('Comic Text Detector')),
    );
    await tester.pumpAndSettle();
    expect(settings.detectorModelId, 'comic_text_detector');
    expect(required, findsNothing);

    final ai = find.byKey(const ValueKey('translation-text-locator-ai'));
    // 回到列表顶部，避免选项停在顶栏下方而点不中。
    await tester.drag(find.byType(Scrollable).last, const Offset(0, 3000));
    await tester.pumpAndSettle();
    await tester.tap(ai);
    await tester.pumpAndSettle();
    expect(settings.textLocator, TranslationTextLocator.ai);
    expect(ctd, findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('AI'), findsWidgets);
  });

  testWidgets('the runtime row gates model selection', (tester) async {
    models.setRuntime(const DetectorModelState());
    models.set(
      'pp_ocrv5_mobile_det',
      const DetectorModelState(status: DetectorModelStatus.installed),
    );
    await pump(tester);
    await openLocator(tester);
    final runtimeRequired = find.text('Download the detection runtime first');
    expect(runtimeRequired, findsOneWidget);
    expect(find.text('Download and select a detection model'), findsNothing);
    final runtimeRow = find.byKey(
      const ValueKey('translation-detector-runtime'),
    );
    expect(
      find.descendant(
        of: runtimeRow,
        matching: find.text('ONNX Runtime ${models.runtime!.version}'),
      ),
      findsOneWidget,
    );
    final mobile = find.byKey(
      const ValueKey('translation-detector-pp_ocrv5_mobile_det'),
    );
    final mobileName = find.descendant(
      of: mobile,
      matching: find.text('PP-OCRv5 Mobile'),
    );
    await tester.ensureVisible(mobileName);
    await tester.pumpAndSettle();
    await tester.tap(mobileName);
    await tester.pumpAndSettle();
    expect(settings.detectorModelId, isNull);

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
    await tester.ensureVisible(mobileName);
    await tester.pumpAndSettle();
    await tester.tap(mobileName);
    await tester.pumpAndSettle();
    expect(settings.detectorModelId, 'pp_ocrv5_mobile_det');
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
    await openLocator(tester);
    final message = find.text(
      "The model source file has changed, so this model can't be used for now",
    );
    await tester.scrollUntilVisible(
      message,
      250,
      scrollable: find.byType(Scrollable).last,
    );
    expect(message, findsOneWidget);
  });

  testWidgets('persists editing and explains missing connection configuration', (
    tester,
  ) async {
    await pump(tester);
    await openProvider(tester);
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

  testWidgets('thinking effort switches with providers', (tester) async {
    await settings.updateProvider(
      preset: TranslationProviderPreset.openai,
      reasoningEffort: TranslationReasoningEffort.high,
    );
    await settings.updateProvider(
      preset: TranslationProviderPreset.gemini,
      reasoningEffort: TranslationReasoningEffort.low,
    );
    await pump(tester);
    await openProvider(tester);
    final effort = find.byType(
      HazukiMenuSettingTile<TranslationReasoningEffort>,
    );
    final provider = find.byType(
      HazukiMenuSettingTile<TranslationProviderPreset>,
    );
    await tester.ensureVisible(effort);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<HazukiMenuSettingTile<TranslationReasoningEffort>>(effort)
          .selected,
      TranslationReasoningEffort.high,
    );
    await tester.tap(effort);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Medium').last);
    await tester.pumpAndSettle();
    expect(settings.reasoningEffort, TranslationReasoningEffort.medium);
    await tester.ensureVisible(provider);
    await tester.pumpAndSettle();
    await tester.tap(provider);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gemini').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(effort);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<HazukiMenuSettingTile<TranslationReasoningEffort>>(effort)
          .selected,
      TranslationReasoningEffort.low,
    );
  });

  testWidgets('custom instructions save and reset', (tester) async {
    await pump(tester);
    await open(tester, find.text('System prompt'));
    final promptField = find.byKey(const ValueKey('translation-system-prompt'));
    await tester.enterText(promptField, 'Preserve honorifics.');
    await tester.pumpAndSettle();
    expect(settings.customSystemPrompt, isEmpty);
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(settings.customSystemPrompt, 'Preserve honorifics.');
    await tester.tap(find.text('Restore default'));
    await tester.pumpAndSettle();
    expect(settings.customSystemPrompt, isEmpty);
    expect(tester.widget<TextField>(promptField).controller!.text, isEmpty);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Default'), findsOneWidget);
  });
}
