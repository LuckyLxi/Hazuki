import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/translation/imaging/bubble_snapper.dart';
import 'package:hazuki/services/translation/imaging/translation_image_processor.dart';
import 'package:hazuki/services/translation/manga_translation_provider.dart';
import 'package:hazuki/services/translation/manga_translation_provider_factory.dart';
import 'package:hazuki/services/translation/manga_translation_service.dart';
import 'package:hazuki/services/translation/manga_translation_settings_store.dart';
import 'package:hazuki/services/translation/models/translation_models.dart';
import 'package:hazuki/services/translation/translation_failure.dart';
import 'package:hazuki/services/translation/translation_glossary_store.dart';
import 'package:hazuki/services/translation/translation_response_parser.dart';
import 'package:hazuki/services/translation/translation_result_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hazuki/services/translation/translation_usage_store.dart';

class _Provider implements MangaTranslationProvider {
  int calls = 0;
  final prompts = <String>[];
  final systemPrompts = <String>[];
  TranslationProviderConfiguration? configuration;
  Future<ProviderRawResponse> Function(int call)? respond;

  @override
  Future<List<String>> listModels({CancelToken? cancelToken}) async => [];

  @override
  Future<ProviderRawResponse> translateImage(
    TranslationImagePayload image,
    String systemPrompt,
    String userPrompt, {
    CancelToken? cancelToken,
  }) async {
    prompts.add(userPrompt);
    systemPrompts.add(systemPrompt);
    calls++;
    return respond?.call(calls) ??
        const ProviderRawResponse(
          text: '{"regions":[],"terms":[{"src":"Alice","dst":"爱丽丝"}]}',
          usage: TranslationUsage(inputTokens: 20, outputTokens: 5),
        );
  }
}

class _Providers extends MangaTranslationProviderFactory {
  _Providers(this.provider);
  final _Provider provider;
  @override
  MangaTranslationProvider create(
    TranslationProviderPreset preset,
    TranslationProviderConfiguration configuration,
  ) {
    provider.configuration = configuration;
    return provider;
  }
}

class _Images extends TranslationImageProcessor {
  int sliceCount = 1;
  int calls = 0;
  @override
  Future<PreparedTranslationImage> prepare(Uint8List bytes) async {
    calls++;
    return PreparedTranslationImage(
      slices: List.generate(
        sliceCount,
        (index) => TranslationImageSlice(
          payload: TranslationImagePayload(
            jpegBytes: bytes,
            width: 1,
            height: 1,
          ),
          top: index / sliceCount,
          bottom: (index + 1) / sliceCount,
          ownedTop: index / sliceCount,
          ownedBottom: (index + 1) / sliceCount,
        ),
      ),
      snapRgba: Uint8List.fromList([255, 255, 255, 255]),
      snapWidth: 1,
      snapHeight: 1,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late _Provider provider;
  late _Images images;
  late MangaTranslationSettingsStore settings;
  late TranslationResultCache cache;
  late TranslationGlossaryStore glossary;
  late MangaTranslationService service;
  late TranslationUsageStore usage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp(
      'hazuki_translation_service_',
    );
    settings = MangaTranslationSettingsStore();
    provider = _Provider();
    final providers = _Providers(provider);
    images = _Images();
    cache = TranslationResultCache(supportDirectory: () async => directory);
    glossary = TranslationGlossaryStore(
      supportDirectory: () async => directory,
    );
    usage = TranslationUsageStore(supportDirectory: () async => directory);
    service = MangaTranslationService(
      settings: settings,
      cache: cache,
      glossary: glossary,
      providers: providers,
      imageProcessor: images,
      snapper: const BubbleSnapper(),
      parser: const TranslationResponseParser(),
      usageStore: usage,
    );
    addTearDown(providers.dispose);
    addTearDown(settings.dispose);
    addTearDown(usage.dispose);
  });
  tearDown(() async {
    await cache.sizeBytes();
    await directory.delete(recursive: true);
  });
  Future<PageTranslationResult> translate({
    bool bypassCache = false,
    CancelToken? token,
  }) => service.translatePage(
    imageBytes: Uint8List.fromList([1]),
    sourceKey: 'source',
    comicId: 'comic',
    bypassCache: bypassCache,
    cancelToken: token,
  );

  test(
    'cache hits avoid preprocessing and providers, while bypass overwrites',
    () async {
      final first = await translate();
      expect(first.usage.inputTokens, 20);
      final cached = await translate();
      expect(cached.usage.inputTokens, 0);
      expect(provider.calls, 1);
      expect(images.calls, 1);
      await translate(bypassCache: true);
      expect(provider.calls, 2);
      expect(images.calls, 2);
      final stats = (await usage.load()).values.single;
      expect(stats.pages, 2);
      expect(stats.requests, 2);
      expect(stats.inputTokens, 40);
    },
  );

  test(
    'changing effort or custom instructions misses old caches and reaches the request',
    () async {
      await translate();
      await settings.setCustomSystemPrompt('Keep the dialogue concise.');
      await translate();
      expect(provider.calls, 2);
      expect(
        provider.systemPrompts.last,
        contains('Keep the dialogue concise.'),
      );
      await settings.updateProvider(
        preset: TranslationProviderPreset.openai,
        reasoningEffort: TranslationReasoningEffort.high,
      );
      await translate();
      expect(provider.calls, 3);
      expect(
        provider.configuration!.reasoningEffort,
        TranslationReasoningEffort.high,
      );
      await translate();
      expect(provider.calls, 3);
    },
  );

  test(
    'injects stored glossary and merges new terms without replacing prior targets',
    () async {
      await glossary.merge('source', 'comic', const [
        TranslationTerm(source: 'Alice', target: '艾丽斯'),
        TranslationTerm(source: 'Bob', target: '鲍勃'),
      ]);
      await translate();
      expect(provider.prompts.single, contains('Alice => 艾丽斯'));
      expect(provider.prompts.single, contains('Bob => 鲍勃'));
      expect(
        (await glossary.load(
          'source',
          'comic',
        )).firstWhere((entry) => entry.source == 'Alice').target,
        '艾丽斯',
      );
    },
  );

  test('requests slices serially and aggregates usage', () async {
    images.sliceCount = 3;
    final pending = Completer<ProviderRawResponse>();
    final started = Completer<void>();
    provider.respond = (call) async {
      if (call == 1) {
        started.complete();
        return pending.future;
      }
      return const ProviderRawResponse(
        text: '{"regions":[],"terms":[]}',
        usage: TranslationUsage(inputTokens: 10, outputTokens: 2),
      );
    };
    final request = translate();
    await started.future;
    expect(provider.calls, 1);
    pending.complete(
      const ProviderRawResponse(
        text: '{"regions":[],"terms":[]}',
        usage: TranslationUsage(inputTokens: 10, outputTokens: 2),
      ),
    );
    final result = await request;
    expect(provider.calls, 3);
    expect(result.usage.inputTokens, 30);
    expect(result.usage.outputTokens, 6);
  });

  test('retries malformed model JSON once and then succeeds', () async {
    provider.respond = (call) async => ProviderRawResponse(
      text: call == 1 ? 'invalid' : '{"regions":[],"terms":[]}',
      usage: const TranslationUsage(inputTokens: 10, outputTokens: 1),
    );
    final result = await translate();
    expect(provider.calls, 2);
    expect(result.usage.inputTokens, 20);
    expect(result.usage.outputTokens, 2);
  });

  test(
    'does not retry badResponse more than once or retry auth failures',
    () async {
      provider.respond = (_) async =>
          throw const TranslationFailure(TranslationFailureKind.badResponse);
      await expectLater(translate(), throwsA(isA<TranslationFailure>()));
      expect(provider.calls, 2);
      provider.calls = 0;
      provider.respond = (_) async =>
          throw const TranslationFailure(TranslationFailureKind.unauthorized);
      await expectLater(
        translate(),
        throwsA(
          isA<TranslationFailure>().having(
            (error) => error.kind,
            'kind',
            TranslationFailureKind.unauthorized,
          ),
        ),
      );
      expect(provider.calls, 1);
    },
  );

  test('honors rate limits and cancels during retry waits', () async {
    final limited = Completer<void>();
    provider.respond = (_) async {
      limited.complete();
      throw const TranslationFailure(
        TranslationFailureKind.rateLimited,
        retryAfter: Duration(seconds: 30),
      );
    };
    final token = CancelToken();
    final assertion = expectLater(
      translate(token: token),
      throwsA(
        isA<TranslationFailure>().having(
          (error) => error.kind,
          'kind',
          TranslationFailureKind.cancelled,
        ),
      ),
    );
    await limited.future;
    token.cancel();
    await assertion;
    expect(provider.calls, 1);
  });

  test(
    'rate limits retry once and cancelled work cannot write results',
    () async {
      provider.respond = (call) async {
        if (call == 1) {
          throw const TranslationFailure(
            TranslationFailureKind.rateLimited,
            retryAfter: Duration.zero,
          );
        }
        return const ProviderRawResponse(
          text: '{"regions":[],"terms":[]}',
          usage: TranslationUsage(),
        );
      };
      await translate();
      expect(provider.calls, 2);
      await cache.clear();
      final token = CancelToken();
      provider.respond = (_) async {
        token.cancel();
        return const ProviderRawResponse(
          text: '{"regions":[],"terms":[]}',
          usage: TranslationUsage(),
        );
      };
      await expectLater(
        translate(token: token),
        throwsA(
          isA<TranslationFailure>().having(
            (error) => error.kind,
            'kind',
            TranslationFailureKind.cancelled,
          ),
        ),
      );
      expect(await cache.sizeBytes(), 0);
    },
  );
}
