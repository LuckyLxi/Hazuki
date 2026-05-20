import 'package:flutter/foundation.dart';

import 'package:hazuki/features/reader/state/reader_mode.dart';
import 'package:hazuki/features/reader/state/reader_settings_store.dart';
import 'package:hazuki/features/reader/support/reader_source_image_quality_settings.dart';
import 'package:hazuki/services/hazuki_source_service.dart';

class ReadingSettingsController extends ChangeNotifier {
  ReadingSettingsController({
    required HazukiSourceService sourceService,
    ReaderSettingsStore settingsStore = const ReaderSettingsStore(),
  }) : _sourceService = sourceService,
       _settingsStore = settingsStore {
    sourceImageQuality = ReaderSourceImageQualitySettings.load(_sourceService);
  }

  final HazukiSourceService _sourceService;
  final ReaderSettingsStore _settingsStore;

  bool _disposed = false;

  ReaderMode readerMode = ReaderSettingsStore.defaultReaderMode;
  bool doublePageMode = ReaderSettingsStore.defaultDoublePageMode;
  bool tapToTurnPage = ReaderSettingsStore.defaultTapToTurnPage;
  bool volumeButtonTurnPage = ReaderSettingsStore.defaultVolumeButtonTurnPage;
  bool immersiveMode = ReaderSettingsStore.defaultImmersiveMode;
  bool keepScreenOn = ReaderSettingsStore.defaultKeepScreenOn;
  bool customBrightness = ReaderSettingsStore.defaultCustomBrightness;
  double brightnessValue = ReaderSettingsStore.defaultBrightnessValue;
  bool pageIndicator = ReaderSettingsStore.defaultPageIndicator;
  bool pinchToZoom = ReaderSettingsStore.defaultPinchToZoom;
  bool longPressToSave = ReaderSettingsStore.defaultLongPressToSave;
  late ReaderSourceImageQualitySnapshot sourceImageQuality;

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> loadSettings() async {
    final settings = await _settingsStore.load();
    final sourceSettings = ReaderSourceImageQualitySettings.load(
      _sourceService,
    );
    if (_disposed) {
      return;
    }
    readerMode = settings.readerMode;
    doublePageMode = settings.doublePageMode;
    tapToTurnPage = settings.tapToTurnPage;
    volumeButtonTurnPage = settings.volumeButtonTurnPage;
    immersiveMode = settings.immersiveMode;
    keepScreenOn = settings.keepScreenOn;
    customBrightness = settings.customBrightness;
    brightnessValue = settings.brightnessValue;
    pageIndicator = settings.pageIndicator;
    pinchToZoom = settings.pinchToZoom;
    longPressToSave = settings.longPressToSave;
    sourceImageQuality = sourceSettings;
    _notify();
  }

  Future<void> updateReaderMode(ReaderMode? value) async {
    if (value == null) {
      return;
    }
    readerMode = value;
    _notify();
    await _settingsStore.saveReaderMode(value);
  }

  Future<void> toggleDoublePageMode(bool value) async {
    doublePageMode = value;
    _notify();
    await _settingsStore.saveDoublePageMode(value);
  }

  Future<void> toggleTapToTurnPage(bool value) async {
    tapToTurnPage = value;
    _notify();
    await _settingsStore.saveTapToTurnPage(value);
  }

  Future<void> toggleVolumeButtonTurnPage(bool value) async {
    volumeButtonTurnPage = value;
    _notify();
    await _settingsStore.saveVolumeButtonTurnPage(value);
  }

  Future<void> toggleImmersiveMode(bool value) async {
    immersiveMode = value;
    _notify();
    await _settingsStore.saveImmersiveMode(value);
  }

  Future<void> toggleKeepScreenOn(bool value) async {
    keepScreenOn = value;
    _notify();
    await _settingsStore.saveKeepScreenOn(value);
  }

  Future<void> toggleCustomBrightness(bool value) async {
    customBrightness = value;
    _notify();
    await _settingsStore.saveCustomBrightness(value);
  }

  Future<void> updateBrightness(double value) async {
    final normalized = ReaderSettingsStore.normalizeBrightnessValue(value);
    brightnessValue = normalized;
    _notify();
    await _settingsStore.saveBrightnessValue(normalized);
  }

  Future<void> togglePageIndicator(bool value) async {
    pageIndicator = value;
    _notify();
    await _settingsStore.savePageIndicator(value);
  }

  Future<void> togglePinchToZoom(bool value) async {
    pinchToZoom = value;
    _notify();
    await _settingsStore.savePinchToZoom(value);
  }

  Future<void> toggleLongPressToSave(bool value) async {
    longPressToSave = value;
    _notify();
    await _settingsStore.saveLongPressToSave(value);
  }

  Future<void> updateCopyMangaImageQuality(String? value) async {
    if (value == null) {
      return;
    }
    final normalized =
        ReaderSourceImageQualitySettings.normalizeCopyMangaImageQuality(value);
    if (normalized == sourceImageQuality.copyMangaImageQuality) {
      return;
    }
    sourceImageQuality = sourceImageQuality.copyWith(
      copyMangaImageQuality: normalized,
    );
    _notify();
    await ReaderSourceImageQualitySettings.updateCopyMangaImageQuality(
      _sourceService,
      normalized,
    );
  }

  Future<void> updatePicacgImageQuality(String? value) async {
    if (value == null) {
      return;
    }
    final normalized =
        ReaderSourceImageQualitySettings.normalizePicacgImageQuality(value);
    if (normalized == sourceImageQuality.picacgImageQuality) {
      return;
    }
    sourceImageQuality = sourceImageQuality.copyWith(
      picacgImageQuality: normalized,
    );
    _notify();
    await ReaderSourceImageQualitySettings.updatePicacgImageQuality(
      _sourceService,
      normalized,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
