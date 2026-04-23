class CloudSyncConfig {
  const CloudSyncConfig({
    required this.enabled,
    required this.url,
    required this.username,
    required this.password,
  });

  final bool enabled;
  final String url;
  final String username;
  final String password;

  bool get isComplete =>
      url.trim().isNotEmpty &&
      username.trim().isNotEmpty &&
      password.trim().isNotEmpty;

  CloudSyncConfig copyWith({
    bool? enabled,
    String? url,
    String? username,
    String? password,
  }) {
    return CloudSyncConfig(
      enabled: enabled ?? this.enabled,
      url: url ?? this.url,
      username: username ?? this.username,
      password: password ?? this.password,
    );
  }
}

class CloudSyncConnectionStatus {
  const CloudSyncConnectionStatus({
    required this.ok,
    required this.message,
    required this.checkedAt,
  });

  final bool ok;
  final String message;
  final DateTime checkedAt;
}

class CloudSyncRestoreResult {
  const CloudSyncRestoreResult({
    required this.restoredSettings,
    required this.restoredReading,
    required this.restoredSearchHistory,
    required this.restoredSourceFile,
    required this.appliedPlatformFilteredKeys,
    required this.skippedKeys,
  });

  final bool restoredSettings;
  final bool restoredReading;
  final bool restoredSearchHistory;
  final bool restoredSourceFile;
  final List<String> appliedPlatformFilteredKeys;
  final List<String> skippedKeys;
}

class CloudSyncLocalSnapshot {
  const CloudSyncLocalSnapshot({
    required this.settings,
    required this.reading,
    required this.searchHistoryJsonl,
    required this.historyCount,
    required this.progressCount,
    required this.searchCount,
    required this.jmSource,
  });

  final String settings;
  final String reading;
  final String searchHistoryJsonl;
  final int historyCount;
  final int progressCount;
  final int searchCount;
  final String? jmSource;
}

class CloudSyncApplySettingsResult {
  const CloudSyncApplySettingsResult({
    required this.appliedPlatformFilteredKeys,
    required this.skippedKeys,
  });

  final List<String> appliedPlatformFilteredKeys;
  final List<String> skippedKeys;
}
