import 'package:get_it/get_it.dart';

import '../services/comment_filter_service.dart';

final GetIt sl = GetIt.instance;

/// Registers app-level services in the dependency injection container.
///
/// Called once during startup, before any service `.instance` accessor is used.
void registerServices() {
  sl.registerLazySingleton<CommentFilterService>(() => CommentFilterService());
}
