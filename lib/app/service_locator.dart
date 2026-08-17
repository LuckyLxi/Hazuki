import 'package:get_it/get_it.dart';

import 'di/application_service_registrar.dart';
import 'di/source_service_registrar.dart';

final GetIt sl = GetIt.instance;

/// Registers the complete application service graph.
///
/// Production uses the global [sl]. Tests and alternate composition roots can
/// supply an isolated [GetIt] instance without depending on global state.
void registerServices({GetIt? locator}) {
  final services = locator ?? sl;
  registerSourceServices(services);
  registerApplicationServices(services);
}
