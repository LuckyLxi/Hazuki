class SourcePrefsKeys {
  const SourcePrefsKeys._();

  static const String cacheMaxBytes = 'image_cache_max_bytes';
  static const String cacheAutoCleanMode = 'image_cache_auto_clean_mode';
  static const String cacheLastAutoCleanAt = 'image_cache_last_auto_clean_at';
  static const String activeSourceKey = 'active_source_key_v1';
  static const String customEditedJmSource = 'custom_edited_jm_source';
  static String customEditedSource(String sourceKey) =>
      'custom_edited_source_$sourceKey';
  static const String softwareLogCaptureEnabled =
      'advanced_software_log_capture_enabled';
  static const String sourceSessionScopeMigration =
      'source_session_scope_migration_v1';
  static const String sourceSecureSessionMigration =
      'source_secure_session_migration_v1';

  static const int defaultCacheMaxBytes = 400 * 1024 * 1024;
  static const String defaultAutoCleanMode = 'size_overflow';
  static const Duration discoverCacheTtl = Duration(days: 1);
  static const double cacheOverflowTrimTargetRatio = 0.75;
}
