import '../../services/translation/manga_translation_service.dart';
import '../../services/translation/manga_translation_settings_store.dart';
import '../../services/translation/translation_glossary_store.dart';
import '../../services/translation/translation_result_cache.dart';
import '../../services/translation/translation_usage_store.dart';
import '../../services/translation/detection/translation_detector_model_store.dart';

class MangaTranslationDependencies {
  const MangaTranslationDependencies({
    required this.settings,
    required this.models,
    required this.service,
    required this.cache,
    required this.glossary,
    required this.usage,
  });
  final MangaTranslationSettingsStore settings;
  final TranslationDetectorModelStore models;
  final MangaTranslationService service;
  final TranslationResultCache cache;
  final TranslationGlossaryStore glossary;
  final TranslationUsageStore usage;
}
