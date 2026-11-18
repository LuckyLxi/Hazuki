Map<String, dynamic> parseSourceSettingsDefaults(dynamic raw) {
  if (raw is! Map) return {};
  final defaults = <String, dynamic>{};
  for (final entry in Map<String, dynamic>.from(raw).entries) {
    final value = entry.value;
    if (value is Map && value.containsKey('default')) {
      defaults[entry.key] = value['default'];
    }
  }
  return defaults;
}
