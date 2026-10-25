import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/translation/detection/translation_detector_model_store.dart';
import 'package:hazuki/services/translation/detection/translation_detector_models.dart';
import 'package:hazuki/services/translation/detection/translation_text_detector.dart';
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
import 'package:image/image.dart' as img;
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

class _Models extends TranslationDetectorModelStore {
  _Models(MangaTranslationSettingsStore settings) : super(settings: settings);

  final installed = {'pp_ocrv5_mobile_det', 'comic_text_detector'};

  @override
  Future<void> load() async {}

  @override
  DetectorModelState stateOf(String id) => DetectorModelState(
    status: installed.contains(id)
        ? DetectorModelStatus.installed
        : DetectorModelStatus.notInstalled,
  );

  @override
  File? modelFile(String id) => isInstalled(id) ? File('$id.onnx') : null;

  bool runtimeInstalled = true;

  @override
  bool get isRuntimeInstalled => runtimeInstalled;

  @override
  File? get runtimeFile => runtimeInstalled ? File('onnxruntime') : null;
}

class _Detector implements TranslationTextDetector {
  int calls = 0, releases = 0;
  final models = <String>[];
  Future<List<Rect>> Function(int call)? respond;

  @override
  Future<List<Rect>> detect(
    DetectionImage image,
    TranslationDetectorModelSpec spec,
    File model,
    File runtime, {
    CancelToken? cancelToken,
  }) async {
    calls++;
    models.add(spec.id);
    return respond?.call(calls) ?? const [];
  }

  @override
  Future<void> release() async => releases++;
}

class _Images extends TranslationImageProcessor {
  int sliceCount = 1;
  int calls = 0;
  final detectionSides = <int?>[];
  PreparedTranslationImage? prepared;
  @override
  Future<PreparedTranslationImage> prepare(
    Uint8List bytes, {
    int? detectionMaxSide,
  }) async {
    calls++;
    detectionSides.add(detectionMaxSide);
    if (prepared != null) return prepared!;
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
          detection: detectionMaxSide == null
              ? null
              : DetectionImage(rgba: Uint8List(4), width: 1, height: 1),
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
  late _Models models;
  late _Detector detector;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp(
      'hazuki_translation_service_',
    );
    settings = MangaTranslationSettingsStore();
    // 既有用例覆盖 AI 定位；本地检测用例各自切换定位方式。
    await settings.setTextLocator(TranslationTextLocator.ai);
    models = _Models(settings);
    detector = _Detector();
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
      models: models,
      detector: detector,
    );
    addTearDown(providers.dispose);
    addTearDown(models.dispose);
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

  test('layout processing invalidates pre-layout AI caches', () async {
    final key = await TranslationResultCache.keyFor(
      imageBytes: Uint8List.fromList([1, 2, 3]),
      targetLanguage: 'zh-Hans',
      providerPreset: TranslationProviderPreset.openai,
      model: 'gpt',
      translateSfx: false,
      reasoningEffort: TranslationReasoningEffort.low,
      customSystemPrompt: 'style',
    );
    // 旧结果把吸附后的框覆盖了原文框，不能作为新排版数据继续使用。
    expect(key, isNot('03bc8b4c9377746499e3bc5fe2becd28c6a69d53'));
  });

  test(
    'keeps source coordinates and caches balloon layout and repairs',
    () async {
      final rgba = Uint8List(100 * 100 * 4);
      for (var y = 0; y < 100; y++) {
        for (var x = 0; x < 100; x++) {
          final offset = (y * 100 + x) * 4;
          final bubble = (x - 50) * (x - 50) + (y - 50) * (y - 50) < 40 * 40;
          final ink = x >= 45 && x < 55 && y >= 30 && y < 70;
          rgba[offset] = ink
              ? 0
              : bubble
              ? 160
              : 80;
          rgba[offset + 1] = ink
              ? 0
              : bubble
              ? 235
              : 80;
          rgba[offset + 2] = ink
              ? 0
              : bubble
              ? 245
              : 80;
          rgba[offset + 3] = 255;
        }
      }
      images.prepared = PreparedTranslationImage(
        slices: [
          TranslationImageSlice(
            payload: TranslationImagePayload(
              jpegBytes: Uint8List(1),
              width: 100,
              height: 100,
            ),
            top: 0,
            bottom: 1,
            ownedTop: 0,
            ownedBottom: 1,
          ),
        ],
        snapRgba: rgba,
        snapWidth: 100,
        snapHeight: 100,
      );
      provider.respond = (_) async => const ProviderRawResponse(
        text:
            '{"regions":[{"box":[450,300,550,700],"kind":"bubble","src":"原文","dst":"Hello there!","vertical":true}]}',
        usage: TranslationUsage(),
      );
      final first = (await translate()).regions.single;
      expect(first.box, const Rect.fromLTRB(0.45, 0.3, 0.55, 0.7));
      expect(first.layoutBox!.width, greaterThan(first.box.width * 3));
      expect(first.textPatches, isNotEmpty);
      final cached = (await translate()).regions.single;
      expect(cached.toJson(), first.toJson());
      expect(provider.calls, 1);
    },
  );

  group('local detection', () {
    const boxA = Rect.fromLTRB(0.1, 0.2, 0.3, 0.3);
    const boxB = Rect.fromLTRB(0.1, 0.3, 0.35, 0.4);

    setUp(() async {
      await settings.setTextLocator(TranslationTextLocator.detector);
      await settings.setDetectorModelId('pp_ocrv5_mobile_det');
    });

    for (final merged in [false, true]) {
      test(
        'completes both staggered lobes from one detector box, merged=$merged',
        () async {
          final image = img.Image(width: 200, height: 240, numChannels: 4);
          img.fill(image, color: img.ColorRgb8(255, 255, 255));
          for (final column in [(60, 110), (85, 30)]) {
            for (var y = column.$2; y < column.$2 + 90; y += 20) {
              img.fillRect(
                image,
                x1: column.$1,
                y1: y,
                x2: column.$1 + 15,
                y2: y + 13,
                color: img.ColorRgb8(0, 0, 0),
              );
            }
          }
          final rgba = image.getBytes(order: img.ChannelOrder.rgba);
          images.prepared = PreparedTranslationImage(
            slices: [
              TranslationImageSlice(
                payload: TranslationImagePayload(
                  jpegBytes: img.encodeJpg(image),
                  width: 200,
                  height: 240,
                ),
                detection: DetectionImage(rgba: rgba, width: 200, height: 240),
                top: 0,
                bottom: 1,
                ownedTop: 0,
                ownedBottom: 1,
              ),
            ],
            snapRgba: rgba,
            snapWidth: 200,
            snapHeight: 240,
          );
          detector.respond = (_) async => const [
            Rect.fromLTRB(58 / 200, 28 / 240, 103 / 200, 205 / 240),
          ];
          provider.respond = (call) async => ProviderRawResponse(
            text: call == 1
                ? merged
                      ? '{"regions":[{"ids":["0-0","0-1"],"kind":"bubble","src":"効率が悪い","dst":"效率很低"}]}'
                      : '{"regions":[{"ids":["0-1"],"kind":"bubble","src":"効率が悪い","dst":"效率很低"}]}'
                : merged
                ? '{"regions":[{"ids":["0-0"],"kind":"bubble","src":"と言えば","dst":"说起来"},{"ids":["0-1"],"kind":"bubble","src":"効率が悪い","dst":"效率很低"}]}'
                : '{"regions":[{"ids":["0-0"],"kind":"bubble","src":"と言えば","dst":"说起来"}]}',
            usage: const TranslationUsage(),
          );
          final result = await translate();
          expect(provider.calls, 2);
          expect(
            result.regions.map((region) => region.translatedText),
            unorderedEquals(['效率很低', '说起来']),
          );
          expect(
            result.regions.every((region) => region.sourceVertical),
            isTrue,
          );
          expect(
            result.regions.map((region) => region.sourceIds.single),
            unorderedEquals(['0-0', '0-1']),
          );
          expect((await translate()).regions, hasLength(2));
          expect(provider.calls, 2);
        },
      );
    }

    test(
      'numbers boxes per slice, unions grouped ids and skips empty slices',
      () async {
        images.sliceCount = 2;
        detector.respond = (call) async => call == 1 ? [boxA, boxB] : [];
        provider.respond = (_) async => const ProviderRawResponse(
          text:
              '{"regions":[{"ids":["0-0","0-1","9-9"],"kind":"bubble","src":"a","dst":"甲","vertical":false},'
              '{"ids":["0-0"],"kind":"bubble","src":"b","dst":"重复"}],"terms":[]}',
          usage: TranslationUsage(inputTokens: 10, outputTokens: 2),
        );
        final result = await translate();
        expect(detector.calls, 2);
        expect(detector.models, everyElement('pp_ocrv5_mobile_det'));
        expect(images.detectionSides.single, 960);
        expect(provider.calls, 1);
        expect(provider.prompts.single, contains('0-0: [100,200,300,300]'));
        expect(provider.prompts.single, contains('0-1: [100,300,350,400]'));
        expect(provider.systemPrompts.single, contains('"ids"'));
        final region = result.regions.single;
        expect(region.translatedText, '甲');
        expect(region.boxSource, TranslationBoxSource.detector);
        // 第一片覆盖页面上半部分，纵向坐标按切片高度回映。
        expect(region.box.left, closeTo(0.1, 1e-9));
        expect(region.box.top, closeTo(0.1, 1e-9));
        expect(region.box.right, closeTo(0.35, 1e-9));
        expect(region.box.bottom, closeTo(0.2, 1e-9));
        final stats = (await usage.load()).values.single;
        expect(stats.requests, 1);
      },
    );

    for (final merged in [false, true]) {
      test('completes missing independent Japanese passages, merged=$merged', () async {
        await settings.setTargetLanguage(TranslationTargetLanguage.japanese);
        detector.respond = (_) async => const [
          Rect.fromLTRB(.4, .1, .5, .35),
          Rect.fromLTRB(.4, .6, .5, .85),
        ];
        provider.respond = (call) async => ProviderRawResponse(
          text: call == 1
              ? merged
                    ? '{"regions":[{"ids":["0-0","0-1"],"kind":"bubble","dst":"一人で見てね！"}]}'
                    : '{"regions":[{"ids":["0-0"],"kind":"bubble","dst":"一人で見てね！"}]}'
              : merged
              ? '{"regions":[{"ids":["0-0"],"kind":"bubble","dst":"一人で見てね！"},{"ids":["0-1"],"kind":"bubble","dst":"今は見ちゃだめ！"}]}'
              : '{"regions":[{"ids":["0-1"],"kind":"bubble","dst":"今は見ちゃだめ！"}]}',
          usage: TranslationUsage(inputTokens: call == 1 ? 10 : 7),
        );
        final result = await translate();
        expect(provider.calls, 2);
        expect(result.regions.map((region) => region.translatedText), [
          '一人で見てね！',
          '今は見ちゃだめ！',
        ]);
        expect(result.regions.map((region) => region.sourceIds), [
          ['0-0'],
          ['0-1'],
        ]);
        expect(result.usage.inputTokens, 17);
        expect(provider.prompts.last, contains('0-1:'));
        if (!merged) expect(provider.prompts.last, isNot(contains('0-0:')));
        final cached = await translate();
        expect(
          cached.regions.map((region) => region.toJson()),
          result.regions.map((region) => region.toJson()),
        );
        expect(provider.calls, 2);
        expect((await usage.load()).values.single.requests, 2);
      });
    }

    test(
      'does not cache a successful page when completion is still missing',
      () async {
        detector.respond = (_) async => const [
          Rect.fromLTRB(.4, .1, .5, .35),
          Rect.fromLTRB(.4, .6, .5, .85),
        ];
        provider.respond = (_) async => const ProviderRawResponse(
          text: '{"regions":[{"ids":["0-0"],"kind":"bubble","dst":"一人で見てね！"}]}',
          usage: TranslationUsage(),
        );
        await expectLater(
          translate(),
          throwsA(
            isA<TranslationFailure>().having(
              (failure) => failure.kind,
              'kind',
              TranslationFailureKind.badResponse,
            ),
          ),
        );
        expect(provider.calls, 3);
        expect(await cache.sizeBytes(), 0);
        expect((await usage.load()).values.single.requests, 3);
      },
    );

    test(
      'explicit non-text detections do not trigger supplementary requests',
      () async {
        detector.respond = (_) async => const [
          Rect.fromLTRB(.4, .1, .5, .35),
          Rect.fromLTRB(.4, .6, .5, .85),
        ];
        provider.respond = (_) async => const ProviderRawResponse(
          text:
              '{"regions":[{"ids":["0-0"],"kind":"bubble","dst":"一人で見てね！"}],'
              '"ignored":[{"ids":["0-1"],"reason":"non_text"}]}',
          usage: TranslationUsage(),
        );
        expect((await translate()).regions, hasLength(1));
        expect(provider.calls, 1);
      },
    );

    test(
      'pages without detected text skip AI but are cached and counted',
      () async {
        final result = await translate();
        expect(result.regions, isEmpty);
        expect(provider.calls, 0);
        final stats = (await usage.load()).values.single;
        expect(stats.pages, 1);
        expect(stats.requests, 0);
        expect(stats.inputTokens, 0);
        await translate();
        expect(detector.calls, 1);
      },
    );

    test('missing models fail before detection or AI', () async {
      models.installed.remove('pp_ocrv5_mobile_det');
      await expectLater(
        translate(),
        throwsA(
          isA<TranslationFailure>().having(
            (error) => error.kind,
            'kind',
            TranslationFailureKind.detectorUnavailable,
          ),
        ),
      );
      await settings.setDetectorModelId(null);
      await expectLater(translate(), throwsA(isA<TranslationFailure>()));
      models.installed.add('pp_ocrv5_mobile_det');
      await settings.setDetectorModelId('pp_ocrv5_mobile_det');
      models.runtimeInstalled = false;
      await expectLater(
        translate(),
        throwsA(
          isA<TranslationFailure>().having(
            (error) => error.kind,
            'kind',
            TranslationFailureKind.detectorUnavailable,
          ),
        ),
      );
      expect(detector.calls, 0);
      expect(provider.calls, 0);
    });

    test('locator and model changes use isolated caches', () async {
      detector.respond = (_) async => [boxA];
      provider.respond = (_) async => const ProviderRawResponse(
        text: '{"regions":[{"ids":["0-0"],"dst":"甲"}],"terms":[]}',
        usage: TranslationUsage(),
      );
      await translate();
      expect(provider.calls, 1);
      await settings.setTextLocator(TranslationTextLocator.ai);
      provider.respond = null;
      await translate();
      expect(provider.calls, 2);
      expect(provider.systemPrompts.last, isNot(contains('"ids"')));
      await settings.setTextLocator(TranslationTextLocator.detector);
      await translate();
      expect(provider.calls, 2);
      provider.respond = (_) async => const ProviderRawResponse(
        text: '{"regions":[{"ids":["0-0"],"kind":"bubble","dst":"甲"}]}',
        usage: TranslationUsage(),
      );
      await settings.setDetectorModelId('comic_text_detector');
      await translate();
      expect(detector.models.last, 'comic_text_detector');
      expect(images.detectionSides.last, 1024);
      expect(provider.calls, 3);
    });

    test(
      'cancelling during detection prevents AI requests and cache writes',
      () async {
        final started = Completer<void>();
        final release = Completer<List<Rect>>();
        detector.respond = (_) {
          started.complete();
          return release.future;
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
        await started.future;
        token.cancel();
        release.complete([boxA]);
        await assertion;
        expect(provider.calls, 0);
        expect(await cache.sizeBytes(), 0);
        expect(await usage.load(), isEmpty);
      },
    );

    test('releases the detector on request', () async {
      await service.releaseDetector();
      expect(detector.releases, 1);
    });
  });
}
