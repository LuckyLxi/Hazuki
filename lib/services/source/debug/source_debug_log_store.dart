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
}
