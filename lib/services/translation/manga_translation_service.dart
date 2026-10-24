import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui';

import 'package:dio/dio.dart';

import 'detection/translation_detector_model_store.dart';
import 'detection/translation_detector_models.dart';
import 'detection/translation_text_detector.dart';
import 'imaging/bubble_snapper.dart';
import 'imaging/translation_image_processor.dart';
import 'manga_translation_provider.dart';
import 'manga_translation_provider_factory.dart';
import 'manga_translation_settings_store.dart';
import 'models/translation_models.dart';
import 'translation_failure.dart';
import 'translation_glossary_store.dart';
import 'translation_prompt.dart';
import 'translation_response_parser.dart';
import 'translation_result_cache.dart';
import 'translation_usage_store.dart';

class MangaTranslationService {
  MangaTranslationService({
    required MangaTranslationSettingsStore settings,
    required TranslationResultCache cache,
    required TranslationGlossaryStore glossary,
    required MangaTranslationProviderFactory providers,
    required TranslationImageProcessor imageProcessor,
    required BubbleSnapper snapper,
    required TranslationResponseParser parser,
    required TranslationUsageStore usageStore,
    required TranslationDetectorModelStore models,
    required TranslationTextDetector detector,
  }) : _settings = settings,
       _cache = cache,
       _glossary = glossary,
       _providers = providers,
       _imageProcessor = imageProcessor,
       _snapper = snapper,
       _parser = parser,
       _usageStore = usageStore,
       _models = models,
       _detector = detector;

  final MangaTranslationSettingsStore _settings;
  final TranslationResultCache _cache;
  final TranslationGlossaryStore _glossary;
  final MangaTranslationProviderFactory _providers;
  final TranslationImageProcessor _imageProcessor;
  final BubbleSnapper _snapper;
  final TranslationResponseParser _parser;
  final TranslationUsageStore _usageStore;
  final TranslationDetectorModelStore _models;
  final TranslationTextDetector _detector;

  /// 释放检测模型会话与工作 isolate；离开阅读器或关闭翻译模式时调用。
  Future<void> releaseDetector() => _detector.release();

  Future<PageTranslationResult> translatePage({
    required Uint8List imageBytes,
    required String sourceKey,
    required String comicId,
    bool bypassCache = false,
    CancelToken? cancelToken,
  }) async {
    try {
      _checkCancelled(cancelToken);
      await _settings.load();
      final preset = _settings.providerPreset;
      final configuration = _settings.configuration;
      final targetLanguage = _settings.targetLanguage;
      final translateSfx = _settings.translateSfx;
      final customSystemPrompt = _settings.customSystemPrompt;
      TranslationDetectorModelSpec? detectorSpec;
      if (_settings.textLocator == TranslationTextLocator.detector) {
        await _models.load();
        detectorSpec = translationDetectorModelSpec(_settings.detectorModelId);
        if (detectorSpec == null ||
            !_models.isInstalled(detectorSpec.id) ||
            !_models.isRuntimeInstalled) {
          throw const TranslationFailure(
            TranslationFailureKind.detectorUnavailable,
          );
        }
      }
      final key = await TranslationResultCache.keyFor(
        imageBytes: imageBytes,
        targetLanguage: targetLanguage.code,
        providerPreset: preset,
        model: configuration.model,
        translateSfx: translateSfx,
        reasoningEffort: configuration.reasoningEffort,
        customSystemPrompt: customSystemPrompt,
        detector: detectorSpec == null
            ? null
            : TranslationDetectorCacheKey(
                modelId: detectorSpec.id,
                modelSha256: detectorSpec.sha256,
              ),
      );
      _checkCancelled(cancelToken);
      if (!bypassCache) {
        final cached = await _cache.read(key);
        _checkCancelled(cancelToken);
        if (cached != null) return cached;
      }
      final prepared = await _imageProcessor.prepare(
        imageBytes,
        detectionMaxSide: detectorSpec?.detectionMaxSide,
      );
      _checkCancelled(cancelToken);
      final glossary = (await _glossary.load(
        sourceKey,
        comicId,
      )).map((entry) => entry.term).toList();
      final systemPrompt = detectorSpec == null
          ? buildTranslationSystemPrompt(
              targetLanguage: targetLanguage,
              translateSfx: translateSfx,
              customInstructions: customSystemPrompt,
            )
          : buildDetectorTranslationSystemPrompt(
              targetLanguage: targetLanguage,
              translateSfx: translateSfx,
              customInstructions: customSystemPrompt,
            );
      MangaTranslationProvider? provider;
      final regions = <TranslationRegion>[];
      final textBoxes = <Rect>[];
      final terms = <TranslationTerm>[];
      var inputTokens = 0, outputTokens = 0;
      for (var index = 0; index < prepared.slices.length; index++) {
        final slice = prepared.slices[index];
        final PageTranslationResult result;
        if (detectorSpec == null) {
          provider ??= _providers.create(preset, configuration);
          result = await _translateSlice(
            provider,
            slice.payload,
            systemPrompt,
            buildTranslationUserPrompt(glossary: glossary),
            (text, usage) =>
                _parser.parse(text, translateSfx: translateSfx, usage: usage),
            cancelToken,
          );
        } else {
          final model = _models.modelFile(detectorSpec.id);
          final runtime = _models.runtimeFile;
          final detection = slice.detection;
          if (model == null || runtime == null) {
            throw const TranslationFailure(
              TranslationFailureKind.detectorUnavailable,
            );
          }
          if (detection == null) {
            throw const TranslationFailure(
              TranslationFailureKind.detectorFailed,
            );
          }
          final detected = await _detector.detect(
            detection,
            detectorSpec,
            model,
            runtime,
            cancelToken: cancelToken,
          );
          _checkCancelled(cancelToken);
          textBoxes.addAll(detected.map(slice.mapRect));
          // 没有检测到文字的切片不调用 AI，也不计请求数和 token。
          if (detected.isEmpty) continue;
          // 框编号带切片序号，避免长图多切片之间重复。
          final boxes = {
            for (var box = 0; box < detected.length; box++)
              '$index-$box': detected[box],
          };
          provider ??= _providers.create(preset, configuration);
          result = await _translateSlice(
            provider,
            slice.payload,
            systemPrompt,
            buildDetectorTranslationUserPrompt(
              boxes: boxes,
              glossary: glossary,
            ),
            (text, usage) => _parser.parseNumbered(
              text,
              boxes: boxes,
              translateSfx: translateSfx,
              usage: usage,
            ),
            cancelToken,
          );
        }
        regions.addAll(slice.mapRegions(result.regions));
        terms.addAll(result.terms);
        inputTokens += result.usage.inputTokens;
        outputTokens += result.usage.outputTokens;
      }
      _checkCancelled(cancelToken);
      final snapped = await _snapInIsolate(
        _snapper,
        prepared,
        regions,
        textBoxes,
      );
      final result = PageTranslationResult(
        regions: [
          for (var index = 0; index < snapped.length; index++)
            TranslationRegion(
              id: 'r$index',
              box: snapped[index].box,
              kind: snapped[index].kind,
              sourceText: snapped[index].sourceText,
              translatedText: snapped[index].translatedText,
              sourceVertical: snapped[index].sourceVertical,
              backgroundColor: snapped[index].backgroundColor,
              boxSource: snapped[index].boxSource,
            ),
        ],
        terms: terms,
        usage: TranslationUsage(
          inputTokens: inputTokens,
          outputTokens: outputTokens,
        ),
      );
      _checkCancelled(cancelToken);
      await _cache.write(key, result);
      _checkCancelled(cancelToken);
      await _glossary.merge(sourceKey, comicId, terms);
      _checkCancelled(cancelToken);
      await _usageStore.record(pages: 1);
      return result;
    } catch (error) {
      _checkCancelled(cancelToken);
      throw TranslationFailure.from(error);
    }
  }

  Future<PageTranslationResult> _translateSlice(
    MangaTranslationProvider provider,
    TranslationImagePayload image,
    String systemPrompt,
    String userPrompt,
    PageTranslationResult Function(String text, TranslationUsage usage) parse,
    CancelToken? cancelToken,
  ) async {
    var inputTokens = 0, outputTokens = 0;
    for (var attempt = 0; ; attempt++) {
      _checkCancelled(cancelToken);
      try {
        ProviderRawResponse? raw;
        try {
          raw = await provider.translateImage(
            image,
            systemPrompt,
            userPrompt,
            cancelToken: cancelToken,
          );
        } finally {
          await _usageStore.record(
            requests: 1,
            usage: raw?.usage ?? const TranslationUsage(),
          );
        }
        inputTokens += raw.usage.inputTokens;
        outputTokens += raw.usage.outputTokens;
        _checkCancelled(cancelToken);
        return parse(
          raw.text,
          TranslationUsage(
            inputTokens: inputTokens,
            outputTokens: outputTokens,
          ),
        );
      } catch (error) {
        _checkCancelled(cancelToken);
        final failure = TranslationFailure.from(error);
        if (attempt > 0 ||
            failure.kind != TranslationFailureKind.rateLimited &&
                failure.kind != TranslationFailureKind.badResponse) {
          throw failure;
        }
        if (failure.kind == TranslationFailureKind.rateLimited) {
          final delay = failure.retryAfter ?? const Duration(seconds: 3);
          await Future.any<void>([
            Future<void>.delayed(
              delay > const Duration(seconds: 10)
                  ? const Duration(seconds: 10)
                  : delay,
            ),
            if (cancelToken != null)
              cancelToken.whenCancel.then<void>(
                (_) => throw const TranslationFailure(
                  TranslationFailureKind.cancelled,
                ),
              ),
          ]);
        }
      }
    }
  }

  // 闭包在静态方法中创建，避免捕获服务实例等无法跨 isolate 发送的上下文。
  static Future<List<TranslationRegion>> _snapInIsolate(
    BubbleSnapper snapper,
    PreparedTranslationImage prepared,
    List<TranslationRegion> regions,
    List<Rect> textBoxes,
  ) {
    final rgba = prepared.snapRgba,
        width = prepared.snapWidth,
        height = prepared.snapHeight;
    return Isolate.run(
      () => snapper.snap(rgba, width, height, regions, textBoxes: textBoxes),
    );
  }

  static void _checkCancelled(CancelToken? token) {
    if (token?.isCancelled ?? false) {
      throw const TranslationFailure(TranslationFailureKind.cancelled);
    }
  }
}
