class SourceMeta {
  const SourceMeta({
    required this.name,
    required this.key,
    required this.version,
    required this.supportsAccount,
    required this.settingsDefaults,
    this.presentation = const {},
    this.settings = const {},
    this.translation = const {},
  });

  final String name;
  final String key;
  final String version;
  final bool supportsAccount;
  final Map<String, dynamic> settingsDefaults;
  final Map<String, dynamic> presentation;
  final Map<String, dynamic> settings;
  final Map<String, dynamic> translation;
}
