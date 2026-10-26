import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'translation_file_queue.dart';

enum TranslationProviderPreset {
  openai('https://api.openai.com/v1'),
  gemini('https://generativelanguage.googleapis.com/v1beta/openai'),
  claude('https://api.anthropic.com/v1'),
  custom('');

  const TranslationProviderPreset(this.defaultBaseUrl);
  final String defaultBaseUrl;
}

enum TranslationBubbleStyle { sampled, white }

/// 思考强度；[off] 显式关闭思考，[providerDefault] 不发送相关参数。
enum TranslationReasoningEffort { providerDefault, off, low, medium, high }

/// 文字区域的定位方式：本地模型检测，或交给 AI 直接返回坐标。
enum TranslationTextLocator { detector, ai }

enum TranslationTargetLanguage {
  simplifiedChinese('zh-Hans', 'Simplified Chinese'),
  traditionalChinese('zh-Hant', 'Traditional Chinese'),
  english('en', 'English'),
  japanese('ja', 'Japanese'),
  korean('ko', 'Korean'),
  spanish('es', 'Spanish'),
  french('fr', 'French'),
  german('de', 'German'),
  russian('ru', 'Russian'),
  portuguese('pt', 'Portuguese');

  const TranslationTargetLanguage(this.code, this.englishName);
  final String code;
  final String englishName;
}

class TranslationProviderConfiguration {
  const TranslationProviderConfiguration({
    required this.baseUrl,
    this.model = '',
    this.apiKey = '',
    this.reasoningEffort = TranslationReasoningEffort.providerDefault,
  });

  final String baseUrl;
  final String model;
  final String apiKey;
  final TranslationReasoningEffort reasoningEffort;

  bool get isConfigured =>
      baseUrl.trim().isNotEmpty &&
      model.trim().isNotEmpty &&
      apiKey.trim().isNotEmpty;
}

class MangaTranslationSettingsStore extends ChangeNotifier {
  MangaTranslationSettingsStore({
    Future<SharedPreferences> Function()? preferences,
    FlutterSecureStorage? secureStorage,
  }) : _preferences = preferences ?? SharedPreferences.getInstance,
       _secureStorage =
           secureStorage ??
           const FlutterSecureStorage(
             aOptions: AndroidOptions(
               storageNamespace: 'hazuki_manga_translation_v1',
             ),
           );

  static const _prefix = 'manga_translation_';
  final Future<SharedPreferences> Function() _preferences;
  final FlutterSecureStorage _secureStorage;
  Future<void>? _loadFuture;
  late SharedPreferences _prefs;
  final _providerWrites = TranslationFileQueue();

  bool _enabled = false;
  bool _readerModeOn = false;
  bool _autoEnableReaderMode = false;
  TranslationProviderPreset _providerPreset = TranslationProviderPreset.openai;
  TranslationTargetLanguage _targetLanguage =
      TranslationTargetLanguage.simplifiedChinese;
  int _prefetchAhead = 3;
  TranslationBubbleStyle _bubbleStyle = TranslationBubbleStyle.sampled;
  bool _translateSfx = false;
  bool _verticalText = true;
  String _customSystemPrompt = '';
  TranslationTextLocator _textLocator = TranslationTextLocator.detector;
  String? _detectorModelId;
  final _configurations = {
    for (final preset in TranslationProviderPreset.values)
      preset: TranslationProviderConfiguration(baseUrl: preset.defaultBaseUrl),
  };

  bool get enabled => _enabled;
  bool get readerModeOn => _readerModeOn;

  /// 进入阅读器时是否沿用上次的翻译开关；关闭时每次进入都从未翻译开始。
  bool get autoEnableReaderMode => _autoEnableReaderMode;
  TranslationProviderPreset get providerPreset => _providerPreset;
  TranslationTargetLanguage get targetLanguage => _targetLanguage;
  int get prefetchAhead => _prefetchAhead;
  TranslationBubbleStyle get bubbleStyle => _bubbleStyle;
  bool get translateSfx => _translateSfx;
  bool get verticalText => _verticalText;
  String get customSystemPrompt => _customSystemPrompt;
  TranslationTextLocator get textLocator => _textLocator;
  String? get detectorModelId => _detectorModelId;
  TranslationProviderConfiguration configurationFor(
    TranslationProviderPreset preset,
  ) => _configurations[preset]!;
  TranslationProviderConfiguration get configuration =>
      configurationFor(providerPreset);
  String get baseUrl => configuration.baseUrl;
  String get model => configuration.model;
  String get apiKey => configuration.apiKey;
  TranslationReasoningEffort get reasoningEffort =>
      configuration.reasoningEffort;
  bool get isConfigured => configuration.isConfigured;

  Future<void> load() => _loadFuture ??= _load();

  Future<void> _load() async {
    final prefs = await _preferences();
    final configurations =
        <TranslationProviderPreset, TranslationProviderConfiguration>{};
    for (final preset in TranslationProviderPreset.values) {
      configurations[preset] = TranslationProviderConfiguration(
        baseUrl:
            prefs.getString('$_prefix${preset.name}_base_url') ??
            preset.defaultBaseUrl,
        model: prefs.getString('$_prefix${preset.name}_model') ?? '',
        apiKey:
            await _secureStorage.read(key: '$_prefix${preset.name}_api_key') ??
            '',
        reasoningEffort: TranslationReasoningEffort.values.firstWhere(
          (value) =>
              value.name ==
              prefs.getString('$_prefix${preset.name}_reasoning_effort'),
          orElse: () => TranslationReasoningEffort.providerDefault,
        ),
      );
    }
    _prefs = prefs;
    _configurations.addAll(configurations);
    _enabled = prefs.getBool('${_prefix}enabled') ?? false;
    _readerModeOn = prefs.getBool('${_prefix}reader_mode_on') ?? false;
    _autoEnableReaderMode =
        prefs.getBool('${_prefix}auto_enable_reader_mode') ?? false;
    _providerPreset = TranslationProviderPreset.values.firstWhere(
      (value) => value.name == prefs.getString('${_prefix}provider_preset'),
      orElse: () => TranslationProviderPreset.openai,
    );
    _targetLanguage = TranslationTargetLanguage.values.firstWhere(
      (value) => value.code == prefs.getString('${_prefix}target_language'),
      orElse: () => TranslationTargetLanguage.simplifiedChinese,
    );
    _prefetchAhead = (prefs.getInt('${_prefix}prefetch_ahead') ?? 3).clamp(
      0,
      5,
    );
    _bubbleStyle = TranslationBubbleStyle.values.firstWhere(
      (value) => value.name == prefs.getString('${_prefix}bubble_style'),
      orElse: () => TranslationBubbleStyle.sampled,
    );
    _translateSfx = prefs.getBool('${_prefix}translate_sfx') ?? false;
    _verticalText = prefs.getBool('${_prefix}vertical_text') ?? true;
    _customSystemPrompt =
        prefs.getString('${_prefix}custom_system_prompt') ?? '';
    _textLocator = TranslationTextLocator.values.firstWhere(
      (value) => value.name == prefs.getString('${_prefix}text_locator'),
      orElse: () => TranslationTextLocator.detector,
    );
    _detectorModelId = prefs.getString('${_prefix}detector_model');
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    await load();
    await _prefs.setBool('${_prefix}enabled', value);
    _enabled = value;
    notifyListeners();
  }

  Future<void> setReaderModeOn(bool value) async {
    await load();
    await _prefs.setBool('${_prefix}reader_mode_on', value);
    _readerModeOn = value;
    notifyListeners();
  }

  Future<void> setProviderPreset(TranslationProviderPreset value) async {
    await load();
    await _prefs.setString('${_prefix}provider_preset', value.name);
    _providerPreset = value;
    notifyListeners();
  }

  Future<void> updateProvider({
    required TranslationProviderPreset preset,
    String? baseUrl,
    String? model,
    String? apiKey,
    TranslationReasoningEffort? reasoningEffort,
  }) => _providerWrites.run(preset.name, () async {
    await load();
    if (baseUrl != null) {
      await _prefs.setString('$_prefix${preset.name}_base_url', baseUrl.trim());
      final current = configurationFor(preset);
      _configurations[preset] = TranslationProviderConfiguration(
        baseUrl: baseUrl.trim(),
        model: current.model,
        apiKey: current.apiKey,
        reasoningEffort: current.reasoningEffort,
      );
    }
    if (model != null) {
      await _prefs.setString('$_prefix${preset.name}_model', model.trim());
      final current = configurationFor(preset);
      _configurations[preset] = TranslationProviderConfiguration(
        baseUrl: current.baseUrl,
        model: model.trim(),
        apiKey: current.apiKey,
        reasoningEffort: current.reasoningEffort,
      );
    }
    if (apiKey != null) {
      await _secureStorage.write(
        key: '$_prefix${preset.name}_api_key',
        value: apiKey.trim(),
      );
      final current = configurationFor(preset);
      _configurations[preset] = TranslationProviderConfiguration(
        baseUrl: current.baseUrl,
        model: current.model,
        apiKey: apiKey.trim(),
        reasoningEffort: current.reasoningEffort,
      );
    }
    if (reasoningEffort != null) {
      await _prefs.setString(
        '$_prefix${preset.name}_reasoning_effort',
        reasoningEffort.name,
      );
      final current = configurationFor(preset);
      _configurations[preset] = TranslationProviderConfiguration(
        baseUrl: current.baseUrl,
        model: current.model,
        apiKey: current.apiKey,
        reasoningEffort: reasoningEffort,
      );
    }
    notifyListeners();
  });

  Future<void> setCustomSystemPrompt(String value) =>
      _providerWrites.run('system_prompt', () async {
        await load();
        final prompt = value.trim();
        await _prefs.setString('${_prefix}custom_system_prompt', prompt);
        _customSystemPrompt = prompt;
        notifyListeners();
      });

  Future<void> setTargetLanguage(TranslationTargetLanguage value) async {
    await load();
    await _prefs.setString('${_prefix}target_language', value.code);
    _targetLanguage = value;
    notifyListeners();
  }

  Future<void> setPrefetchAhead(int value) async {
    RangeError.checkValueInInterval(value, 0, 5, 'prefetchAhead');
    await load();
    await _prefs.setInt('${_prefix}prefetch_ahead', value);
    _prefetchAhead = value;
    notifyListeners();
  }

  Future<void> setBubbleStyle(TranslationBubbleStyle value) async {
    await load();
    await _prefs.setString('${_prefix}bubble_style', value.name);
    _bubbleStyle = value;
    notifyListeners();
  }

  Future<void> setAutoEnableReaderMode(bool value) async {
    await load();
    await _prefs.setBool('${_prefix}auto_enable_reader_mode', value);
    _autoEnableReaderMode = value;
    notifyListeners();
  }

  Future<void> setTranslateSfx(bool value) async {
    await load();
    await _prefs.setBool('${_prefix}translate_sfx', value);
    _translateSfx = value;
    notifyListeners();
  }

  Future<void> setVerticalText(bool value) async {
    await load();
    await _prefs.setBool('${_prefix}vertical_text', value);
    _verticalText = value;
    notifyListeners();
  }

  Future<void> setTextLocator(TranslationTextLocator value) async {
    await load();
    await _prefs.setString('${_prefix}text_locator', value.name);
    _textLocator = value;
    notifyListeners();
  }

  Future<void> setDetectorModelId(String? value) async {
    await load();
    if (value == null) {
      await _prefs.remove('${_prefix}detector_model');
    } else {
      await _prefs.setString('${_prefix}detector_model', value);
    }
    _detectorModelId = value;
    notifyListeners();
  }
}
