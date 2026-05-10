import 'package:get_it/get_it.dart';

final GetIt sl = GetIt.instance;

/// Registers app-level services in the dependency injection container.
///
/// Called once during startup, before any service `.instance` accessor is used.
/// Stage 0 of the architecture refactor only sets up the container; subsequent
/// stages will move each service's static singleton to delegate through `sl`.
void registerServices() {
  // Intentionally empty for Stage 0. Service registrations land in Stage 1.
}
