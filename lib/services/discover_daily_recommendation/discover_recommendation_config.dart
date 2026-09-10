abstract final class DiscoverDailyRecommendationConfig {
  static const String authorsAssetPath = 'assets/data/authors.txt';
  static const int recommendationCount = 7;
  static const int maxAuthorSearchAttempts = 20;
  static const int maxConsecutiveSearchFailures = 3;
  static const int cacheSchemaVersion = 2;
  static const Duration cacheTtl = Duration(minutes: 15);
}
