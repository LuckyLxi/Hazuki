import 'detection/translation_detector_model_store.dart';
import 'manga_translation_settings_store.dart';

/// 阅读器翻译是否可用：服务商已配置，且采用 AI 定位，或检测运行库已安装、
/// 并已选用一个已安装的检测模型。
bool isMangaTranslationReady(
  MangaTranslationSettingsStore settings,
  TranslationDetectorModelStore models,
) =>
    settings.isConfigured &&
    (settings.textLocator == TranslationTextLocator.ai ||
        models.isRuntimeInstalled &&
            models.isInstalled(settings.detectorModelId));
