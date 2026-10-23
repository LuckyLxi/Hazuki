import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/translation/manga_translation_settings_store.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockSecureStorage secureStorage;
  late Map<String, String> secrets;

  MangaTranslationSettingsStore createStore() {
    final store = MangaTranslationSettingsStore(secureStorage: secureStorage);
    addTearDown(store.dispose);
    return store;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    secrets = {};
    secureStorage = _MockSecureStorage();
    when(
      () => secureStorage.read(key: any(named: 'key')),
    ).thenAnswer((call) async => secrets[call.namedArguments[#key]]);
    when(
      () => secureStorage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((call) async {
      secrets[call.namedArguments[#key] as String] =
          call.namedArguments[#value] as String;
    });
  });

  test('loads documented defaults and each preset URL', () async {
    final store = createStore();
    await store.load();

    expect(store.enabled, isFalse);
    expect(store.readerModeOn, isFalse);
    expect(store.providerPreset, TranslationProviderPreset.openai);
    expect(store.targetLanguage.code, 'zh-Hans');
    expect(store.prefetchAhead, 3);
    expect(store.bubbleStyle, TranslationBubbleStyle.sampled);
    expect(store.translateSfx, isFalse);
    expect(store.customSystemPrompt, isEmpty);
    expect(store.reasoningEffort, TranslationReasoningEffort.providerDefault);
    expect(store.isConfigured, isFalse);
    for (final preset in TranslationProviderPreset.values) {
      final config = store.configurationFor(preset);
      expect(config.baseUrl, preset.defaultBaseUrl);
      expect(config.model, isEmpty);
      expect(config.apiKey, isEmpty);
      expect(
        config.reasoningEffort,
        TranslationReasoningEffort.providerDefault,
      );
    }
  });

  test(
    'persists thinking effort per provider and preserves it when credentials change',
    () async {
      final store = createStore();
      for (final preset in TranslationProviderPreset.values) {
        await store.updateProvider(
          preset: preset,
          reasoningEffort: TranslationReasoningEffort.values[preset.index],
        );
        await store.updateProvider(
          preset: preset,
          model: '${preset.name}-model',
          apiKey: 'secret',
          baseUrl: 'https://${preset.name}.example',
        );
      }
      final restored = createStore();
      await restored.load();
      for (final preset in TranslationProviderPreset.values) {
        await restored.setProviderPreset(preset);
        expect(
          restored.reasoningEffort,
          TranslationReasoningEffort.values[preset.index],
        );
      }
    },
  );

  test(
    'saves custom instructions globally and clears them to restore defaults',
    () async {
      final store = createStore();
      await store.setCustomSystemPrompt(
        '  Keep character names consistent.\nUse natural dialogue.  ',
      );
      final restored = createStore();
      await restored.load();
      expect(
        restored.customSystemPrompt,
        'Keep character names consistent.\nUse natural dialogue.',
      );
      await restored.setProviderPreset(TranslationProviderPreset.claude);
      expect(restored.customSystemPrompt, store.customSystemPrompt);
      await restored.setCustomSystemPrompt('');
      final cleared = createStore();
      await cleared.load();
      expect(cleared.customSystemPrompt, isEmpty);
    },
  );

  test('persists settings and notifies after changes', () async {
    final store = createStore();
    await store.load();
    var notifications = 0;
    store.addListener(() => notifications++);

    await store.setEnabled(true);
    await store.setReaderModeOn(true);
    await store.setProviderPreset(TranslationProviderPreset.gemini);
    await store.setTargetLanguage(TranslationTargetLanguage.traditionalChinese);
    await store.setPrefetchAhead(5);
    await store.setBubbleStyle(TranslationBubbleStyle.white);
    await store.setTranslateSfx(true);

    expect(notifications, 7);
    final restored = createStore();
    await restored.load();
    expect(restored.enabled, isTrue);
    expect(restored.readerModeOn, isTrue);
    expect(restored.providerPreset, TranslationProviderPreset.gemini);
    expect(restored.targetLanguage.code, 'zh-Hant');
    expect(restored.prefetchAhead, 5);
    expect(restored.bubbleStyle, TranslationBubbleStyle.white);
    expect(restored.translateSfx, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getKeys().every((key) => key.startsWith('manga_translation_')),
      isTrue,
    );
  });

  test('keeps URL, model, and secure key separate for all presets', () async {
    final store = createStore();
    for (final preset in TranslationProviderPreset.values) {
      await store.updateProvider(
        preset: preset,
        baseUrl: ' https://${preset.name}.example/v1 ',
        model: ' ${preset.name}-model ',
        apiKey: ' ${preset.name}-secret ',
      );
    }

    final restored = createStore();
    await restored.load();
    for (final preset in TranslationProviderPreset.values) {
      await restored.setProviderPreset(preset);
      expect(restored.baseUrl, 'https://${preset.name}.example/v1');
      expect(restored.model, '${preset.name}-model');
      expect(restored.apiKey, '${preset.name}-secret');
      expect(restored.isConfigured, isTrue);
    }
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys().where((key) => key.contains('api_key')), isEmpty);
    expect(
      prefs.getKeys().any(
        (key) => prefs.get(key).toString().contains('-secret'),
      ),
      isFalse,
    );

    await restored.updateProvider(
      preset: TranslationProviderPreset.custom,
      apiKey: '',
    );
    expect(restored.isConfigured, isFalse);
    expect(restored.model, 'custom-model');
    expect(restored.baseUrl, 'https://custom.example/v1');
  });

  test('rejects prefetch counts outside the supported range', () async {
    final store = createStore();
    await expectLater(store.setPrefetchAhead(-1), throwsRangeError);
    await expectLater(store.setPrefetchAhead(6), throwsRangeError);
    await store.setPrefetchAhead(0);
    expect(store.prefetchAhead, 0);
  });

  test('does not report a key as saved when secure storage fails', () async {
    final store = createStore();
    await store.load();
    when(
      () => secureStorage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenThrow(StateError('secure write failed'));

    await expectLater(
      store.updateProvider(
        preset: TranslationProviderPreset.openai,
        apiKey: 'secret',
      ),
      throwsStateError,
    );
    expect(store.apiKey, isEmpty);
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
  });

  test('concurrent load calls share initialization', () async {
    final store = createStore();
    await Future.wait([store.load(), store.load()]);
    for (final preset in TranslationProviderPreset.values) {
      verify(
        () =>
            secureStorage.read(key: 'manga_translation_${preset.name}_api_key'),
      ).called(1);
    }
  });

  test('normalizes invalid persisted enum values and prefetch count', () async {
    SharedPreferences.setMockInitialValues({
      'manga_translation_provider_preset': 'removed',
      'manga_translation_target_language': 'unknown',
      'manga_translation_bubble_style': 'unknown',
      'manga_translation_prefetch_ahead': 99,
      'manga_translation_openai_reasoning_effort': 'unsupported',
    });
    final store = createStore();
    await store.load();
    expect(store.providerPreset, TranslationProviderPreset.openai);
    expect(store.targetLanguage, TranslationTargetLanguage.simplifiedChinese);
    expect(store.bubbleStyle, TranslationBubbleStyle.sampled);
    expect(store.prefetchAhead, 5);
    expect(store.reasoningEffort, TranslationReasoningEffort.providerDefault);
  });
}
