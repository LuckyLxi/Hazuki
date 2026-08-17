import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:hazuki/app/service_locator.dart';
import 'package:hazuki/services/cloud_sync_service.dart';
import 'package:hazuki/services/local_favorites/local_favorites_contracts.dart';
import 'package:hazuki/services/source/runtime/source_runtime_assembly.dart';
import 'package:hazuki/services/source/source_capabilities.dart';

void main() {
  test('registers the service graph in an isolated locator', () async {
    final services = GetIt.asNewInstance();
    addTearDown(services.reset);

    registerServices(locator: services);

    expect(services.isRegistered<SourceRuntimeAssembly>(), isTrue);
    expect(services.isRegistered<SourceSearchGateway>(), isTrue);
    expect(services.isRegistered<LocalFavoritesRepository>(), isTrue);
    expect(services.isRegistered<CloudSyncService>(), isTrue);
    expect(sl.isRegistered<SourceRuntimeAssembly>(), isFalse);
  });

  test('keeps composition-root overrides when registering', () async {
    final services = GetIt.asNewInstance();
    final assembly = SourceRuntimeAssembly();
    addTearDown(services.reset);
    services.registerSingleton<SourceRuntimeAssembly>(assembly);

    registerServices(locator: services);

    expect(services<SourceRuntimeAssembly>(), same(assembly));
    expect(services<SourceSearchGateway>(), same(assembly.gateways.search));
  });
}
