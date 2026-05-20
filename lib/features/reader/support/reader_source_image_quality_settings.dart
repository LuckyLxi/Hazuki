import 'package:hazuki/services/hazuki_source_service.dart';

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
    HazukiSourceService sourceService,
  ) {
    final copyMangaImageQuality = normalizeCopyMangaImageQuality(
      sourceService.loadActiveSourceSetting(copyMangaSettingKey),
    );
    final picacgImageQuality = normalizePicacgImageQuality(
      sourceService.loadActiveSourceSetting(picacgSettingKey),
    );

    return ReaderSourceImageQualitySnapshot(
      isCopyMangaSource: sourceService.isActiveCopyMangaSource,
      isPicacgSource: isHazukiPicacgSourceKey(sourceService.activeSourceKey),
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
    HazukiSourceService sourceService,
    String value,
  ) {
    return sourceService.updateActiveSourceSetting(
      copyMangaSettingKey,
      normalizeCopyMangaImageQuality(value),
    );
  }

  static Future<void> updatePicacgImageQuality(
    HazukiSourceService sourceService,
    String value,
  ) {
    return sourceService.updateActiveSourceSetting(
      picacgSettingKey,
      normalizePicacgImageQuality(value),
    );
  }
}
