import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/services/source/plugins/source_plugin_buttons.dart';

class ReaderSourceImageQualitySnapshot {
  const ReaderSourceImageQualitySnapshot({
    this.settingKey,
    this.options = const {},
    this.value = '',
    this.title = 'Image quality',
    this.locations = const {},
  });

  static const defaults = ReaderSourceImageQualitySnapshot();
  final String? settingKey;
  final Map<String, String> options;
  final String value;
  final String title;
  final Set<SourcePluginButtonLocation> locations;

  bool isVisibleAt(SourcePluginButtonLocation location) =>
      settingKey != null && options.isNotEmpty && locations.contains(location);

  String normalize(String? value) =>
      options.containsKey(value) ? value! : this.value;

  ReaderSourceImageQualitySnapshot copyWith({String? value}) =>
      ReaderSourceImageQualitySnapshot(
        settingKey: settingKey,
        options: options,
        title: title,
        locations: locations,
        value: value ?? this.value,
      );
}

class ReaderSourceImageQualitySettings {
  const ReaderSourceImageQualitySettings._();

  static ReaderSourceImageQualitySnapshot load(
    SourceSettingsGateway sourceService,
    String sourceKey,
  ) {
    final spec = sourceService.presentationForSource(sourceKey) ?? {};
    final key = spec['imageQualitySetting']?.toString();
    final rawOptions = spec['imageQualityOptions'];
    final options = rawOptions is Map
        ? rawOptions.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          )
        : <String, String>{};
    final requested = key == null
        ? ''
        : sourceService.loadSourceSetting(sourceKey, key)?.toString() ??
              spec['imageQualityDefault']?.toString() ??
              '';
    return ReaderSourceImageQualitySnapshot(
      settingKey: key,
      options: options,
      value: options.containsKey(requested)
          ? requested
          : options.keys.firstOrNull ?? '',
      title: spec['imageQualityTitle']?.toString() ?? 'Image quality',
      locations: SourcePluginButton.parseList(spec['buttons'])
          .where((button) => button.id == 'imageQuality')
          .map((button) => button.location)
          .toSet(),
    );
  }

  static Future<void> updateImageQuality(
    SourceSettingsGateway sourceService,
    String sourceKey,
    String value,
  ) {
    final key = sourceService
        .presentationForSource(sourceKey)?['imageQualitySetting']
        ?.toString();
    if (key == null) return Future.value();
    return sourceService.updateSourceSetting(sourceKey, key, value);
  }
}
