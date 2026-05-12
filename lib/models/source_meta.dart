class SourceMeta {
  const SourceMeta({
    required this.name,
    required this.key,
    required this.version,
    required this.supportsAccount,
    required this.settingsDefaults,
  });

  final String name;
  final String key;
  final String version;
  final bool supportsAccount;
  final Map<String, dynamic> settingsDefaults;
}
