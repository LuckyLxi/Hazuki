/// Source-specific diagnostic side data.
///
/// Application log events live in [AppLogStore]; this object deliberately
/// retains only state that belongs to one source runtime.
class SourceDebugLogStore {
  Map<String, dynamic>? favoritesDebugCache;
  bool isWarmingUpFavoritesDebug = false;
  bool softwareLogCaptureEnabled = false;
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
    lastLoginDebugInfoStorage = null;
    lastSourceVersionDebugInfoStorage = null;
  }
}
