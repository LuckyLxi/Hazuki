import '../../services/translation/manga_translation_provider_factory.dart';
import '../../services/translation/manga_translation_service.dart';
import '../../services/translation/manga_translation_settings_store.dart';
import '../../services/translation/translation_glossary_store.dart';
import '../../services/translation/translation_response_parser.dart';
import '../../services/translation/translation_result_cache.dart';
import '../../services/translation/translation_usage_store.dart';

class MangaTranslationDependencies {
  const MangaTranslationDependencies({
    required this.settings,
    required this.service,
    required this.providers,
    required this.cache,
    required this.glossary,
    required this.parser,
    required this.usage,
  });
  final MangaTranslationSettingsStore settings;
  final MangaTranslationService service;
  final MangaTranslationProviderFactory providers;
  final TranslationResultCache cache;
  final TranslationGlossaryStore glossary;
  final TranslationResponseParser parser;
  final TranslationUsageStore usage;
}
