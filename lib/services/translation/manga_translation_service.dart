import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:dio/dio.dart';

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
  }) : _settings = settings,
       _cache = cache,
       _glossary = glossary,
       _providers = providers,
       _imageProcessor = imageProcessor,
       _snapper = snapper,
       _parser = parser,
       _usageStore = usageStore;

  final MangaTranslationSettingsStore _settings;
  final TranslationResultCache _cache;
  final TranslationGlossaryStore _glossary;
  final MangaTranslationProviderFactory _providers;
  final TranslationImageProcessor _imageProcessor;
  final BubbleSnapper _snapper;
  final TranslationResponseParser _parser;
  final TranslationUsageStore _usageStore;

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
      final key = await TranslationResultCache.keyFor(
        imageBytes: imageBytes,
        targetLanguage: targetLanguage.code,
        providerPreset: preset,
        model: configuration.model,
        translateSfx: translateSfx,
      );
      _checkCancelled(cancelToken);
      if (!bypassCache) {
        final cached = await _cache.read(key);
        _checkCancelled(cancelToken);
        if (cached != null) return cached;
      }
      final prepared = await _imageProcessor.prepare(imageBytes);
      _checkCancelled(cancelToken);
      final glossary = await _glossary.load(sourceKey, comicId);
      final systemPrompt = buildTranslationSystemPrompt(
        targetLanguage: targetLanguage,
        translateSfx: translateSfx,
      );
      final userPrompt = buildTranslationUserPrompt(
        glossary: glossary.map((entry) => entry.term).toList(),
      );
      final provider = _providers.create(preset, configuration);
      final regions = <TranslationRegion>[];
      final terms = <TranslationTerm>[];
      var inputTokens = 0, outputTokens = 0;
      for (final slice in prepared.slices) {
        final result = await _translateSlice(
          provider,
          slice.payload,
          systemPrompt,
          userPrompt,
          translateSfx,
          cancelToken,
        );
        regions.addAll(slice.mapRegions(result.regions));
        terms.addAll(result.terms);
        inputTokens += result.usage.inputTokens;
        outputTokens += result.usage.outputTokens;
      }
      _checkCancelled(cancelToken);
      final rgba = prepared.snapRgba,
          width = prepared.snapWidth,
          height = prepared.snapHeight;
      final snapper = _snapper;
      final snapped = await Isolate.run(
        () => snapper.snap(rgba, width, height, regions),
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
    bool translateSfx,
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
        return _parser.parse(
          raw.text,
          translateSfx: translateSfx,
          usage: TranslationUsage(
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

  static void _checkCancelled(CancelToken? token) {
    if (token?.isCancelled ?? false) {
      throw const TranslationFailure(TranslationFailureKind.cancelled);
    }
  }
}
