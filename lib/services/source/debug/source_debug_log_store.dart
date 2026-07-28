class SourceDebugLogStore {
  Map<String, dynamic>? favoritesDebugCache;
  bool isWarmingUpFavoritesDebug = false;
  bool softwareLogCaptureEnabled = false;
  final List<Map<String, dynamic>> recentNetworkLogs = [];
  final List<Map<String, dynamic>> recentApplicationLogs = [];
  final List<Map<String, dynamic>> recentReaderLogs = [];
  final List<Map<String, dynamic>> recentErrorLogs = [];
  final List<Map<String, dynamic>> recentActionLogs = [];
  final List<Map<String, dynamic>> recentSystemLogs = [];
  final List<Map<String, dynamic>> recentPerformanceLogs = [];
  int networkLogDedupedCount = 0;
  DateTime? lastAgeCleanupAt;
  Map<String, dynamic>? lastLoginDebugInfoStorage;
  Map<String, dynamic>? lastSourceVersionDebugInfoStorage;

  Map<String, dynamic>? get lastLoginDebugInfo =>
      softwareLogCaptureEnabled ? lastLoginDebugInfoStorage : null;
  set lastLoginDebugInfo(Map<String, dynamic>? value) {
    lastLoginDebugInfoStorage = softwareLogCaptureEnabled ? value : null;
  }

  Map<String, dynamic>? get lastSourceVersionDebugInfo =>
      softwareLogCaptureEnabled ? lastSourceVersionDebugInfoStorage : null;
  set lastSourceVersionDebugInfo(Map<String, dynamic>? value) {
    lastSourceVersionDebugInfoStorage = softwareLogCaptureEnabled
        ? value
        : null;
  }

  void clearCapturedLogs() {
    favoritesDebugCache = null;
    recentNetworkLogs.clear();
    recentApplicationLogs.clear();
    recentReaderLogs.clear();
    recentErrorLogs.clear();
    recentActionLogs.clear();
    recentSystemLogs.clear();
    recentPerformanceLogs.clear();
    networkLogDedupedCount = 0;
    lastLoginDebugInfoStorage = null;
    lastSourceVersionDebugInfoStorage = null;
  }

  /// Retains captured diagnostics when a source runtime is recreated.
  void copyCapturedLogsFrom(SourceDebugLogStore previous) {
    favoritesDebugCache = previous.favoritesDebugCache;
    isWarmingUpFavoritesDebug = previous.isWarmingUpFavoritesDebug;
    softwareLogCaptureEnabled = previous.softwareLogCaptureEnabled;
    _copyEntries(recentNetworkLogs, previous.recentNetworkLogs);
    _copyEntries(recentApplicationLogs, previous.recentApplicationLogs);
    _copyEntries(recentReaderLogs, previous.recentReaderLogs);
    _copyEntries(recentErrorLogs, previous.recentErrorLogs);
    _copyEntries(recentActionLogs, previous.recentActionLogs);
    _copyEntries(recentSystemLogs, previous.recentSystemLogs);
    _copyEntries(recentPerformanceLogs, previous.recentPerformanceLogs);
    networkLogDedupedCount = previous.networkLogDedupedCount;
    lastAgeCleanupAt = previous.lastAgeCleanupAt;
    lastLoginDebugInfoStorage = previous.lastLoginDebugInfoStorage;
    lastSourceVersionDebugInfoStorage =
        previous.lastSourceVersionDebugInfoStorage;
  }

  void _copyEntries(
    List<Map<String, dynamic>> target,
    List<Map<String, dynamic>> source,
  ) {
    target
      ..clear()
      ..addAll(source.map(Map<String, dynamic>.from));
  }
}
