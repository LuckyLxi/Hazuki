import 'package:hazuki/services/source/source_capabilities.dart';

class ReaderSourceImageQualitySnapshot {
  const ReaderSourceImageQualitySnapshot({
    required this.isCopyMangaSource,
    required this.isPicacgSource,
    required this.copyMangaImageQuality,
    required this.picacgImageQuality,
  });

  static const defaults = ReaderSourceImageQualitySnapshot(
    isCopyMangaSource: false,
    isPicacgSource: false,
    copyMangaImageQuality:
        ReaderSourceImageQualitySettings.defaultCopyMangaImageQuality,
    picacgImageQuality:
        ReaderSourceImageQualitySettings.defaultPicacgImageQuality,
  );

  final bool isCopyMangaSource;
  final bool isPicacgSource;
  final String copyMangaImageQuality;
  final String picacgImageQuality;

  ReaderSourceImageQualitySnapshot copyWith({
    bool? isCopyMangaSource,
    bool? isPicacgSource,
    String? copyMangaImageQuality,
    String? picacgImageQuality,
  }) {
    return ReaderSourceImageQualitySnapshot(
      isCopyMangaSource: isCopyMangaSource ?? this.isCopyMangaSource,
      isPicacgSource: isPicacgSource ?? this.isPicacgSource,
      copyMangaImageQuality:
          copyMangaImageQuality ?? this.copyMangaImageQuality,
      picacgImageQuality: picacgImageQuality ?? this.picacgImageQuality,
    );
  }
}

class ReaderSourceImageQualitySettings {
  const ReaderSourceImageQualitySettings._();

  static const copyMangaSettingKey = 'image_quality';
  static const picacgSettingKey = 'imageQuality';

  static const defaultCopyMangaImageQuality = '1500';
  static const defaultPicacgImageQuality = 'original';

  static const copyMangaImageQualityValues = <String>{'800', '1200', '1500'};
  static const picacgImageQualityValues = <String>{'original', 'medium', 'low'};

  static ReaderSourceImageQualitySnapshot load(
    SourceSettingsGateway sourceService,
    String sourceKey,
  ) {
    final copyMangaImageQuality = normalizeCopyMangaImageQuality(
      sourceService.loadSourceSetting(sourceKey, copyMangaSettingKey),
    );
    final picacgImageQuality = normalizePicacgImageQuality(
      sourceService.loadSourceSetting(sourceKey, picacgSettingKey),
    );

    return ReaderSourceImageQualitySnapshot(
      isCopyMangaSource: isHazukiCopyMangaSourceKey(sourceKey),
      isPicacgSource: isHazukiPicacgSourceKey(sourceKey),
      copyMangaImageQuality: copyMangaImageQuality,
      picacgImageQuality: picacgImageQuality,
    );
  }

  static String normalizeCopyMangaImageQuality(Object? value) {
    final text = value?.toString();
    return copyMangaImageQualityValues.contains(text)
        ? text!
        : defaultCopyMangaImageQuality;
  }

  static String normalizePicacgImageQuality(Object? value) {
    final text = value?.toString();
    return picacgImageQualityValues.contains(text)
        ? text!
        : defaultPicacgImageQuality;
  }

  static Future<void> updateCopyMangaImageQuality(
    SourceSettingsGateway sourceService,
    String sourceKey,
    String value,
  ) {
    return sourceService.updateSourceSetting(
      sourceKey,
      copyMangaSettingKey,
      normalizeCopyMangaImageQuality(value),
    );
  }

  static Future<void> updatePicacgImageQuality(
    SourceSettingsGateway sourceService,
    String sourceKey,
    String value,
  ) {
    return sourceService.updateSourceSetting(
      sourceKey,
      picacgSettingKey,
      normalizePicacgImageQuality(value),
    );
  }
}
