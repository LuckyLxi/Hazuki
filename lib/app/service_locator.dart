import 'package:get_it/get_it.dart';

import '../services/comment_filter_service.dart';
import '../services/discover_daily_recommendation_service.dart';
import '../services/local_favorites_service.dart';
import '../services/manga_download/manga_download_service.dart';
import '../services/password_lock_service.dart';
import '../services/software_update/software_update_download_service.dart';
import '../services/software_update/software_update_service.dart';

final GetIt sl = GetIt.instance;

/// Registers app-level services in the dependency injection container.
///
/// Called once during startup, before any service `.instance` accessor is used.
void registerServices() {
  if (!sl.isRegistered<CommentFilterService>()) {
    sl.registerLazySingleton<CommentFilterService>(() => CommentFilterService());
  }
  if (!sl.isRegistered<LocalFavoritesService>()) {
    sl.registerLazySingleton<LocalFavoritesService>(() => LocalFavoritesService());
  }
  if (!sl.isRegistered<PasswordLockService>()) {
    sl.registerLazySingleton<PasswordLockService>(() => PasswordLockService());
  }
  if (!sl.isRegistered<SoftwareUpdateDownloadService>()) {
    sl.registerLazySingleton<SoftwareUpdateDownloadService>(
      () => SoftwareUpdateDownloadService(),
    );
  }
  if (!sl.isRegistered<SoftwareUpdateService>()) {
    sl.registerLazySingleton<SoftwareUpdateService>(
      () => SoftwareUpdateService(),
    );
  }
  if (!sl.isRegistered<MangaDownloadService>()) {
    sl.registerLazySingleton<MangaDownloadService>(() => MangaDownloadService());
  }
  if (!sl.isRegistered<DiscoverDailyRecommendationService>()) {
    sl.registerLazySingleton<DiscoverDailyRecommendationService>(
      () => DiscoverDailyRecommendationService(),
    );
  }
}
