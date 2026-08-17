import 'package:get_it/get_it.dart';

import '../../services/source/runtime/source_runtime_assembly.dart';
import '../../services/source/source_capabilities.dart';

/// Registers the source runtime and its focused gateway contracts.
///
/// Accepting a locator explicitly keeps this module independent from the
/// application's global service locator and makes the registration graph
/// reusable in isolated tests.
void registerSourceServices(GetIt services) {
  if (!services.isRegistered<SourceRuntimeAssembly>()) {
    services.registerLazySingleton<SourceRuntimeAssembly>(
      SourceRuntimeAssembly.new,
    );
  }
  if (!services.isRegistered<SourceRuntimeRegistry>()) {
    services.registerLazySingleton<SourceRuntimeRegistry>(
      () => services<SourceRuntimeAssembly>().runtimeRegistry,
    );
  }

  _registerGateway<SourceSearchGateway>(services, (a) => a.gateways.search);
  _registerGateway<SourceDiscoverGateway>(services, (a) => a.gateways.discover);
  _registerGateway<SourceFavoriteGateway>(services, (a) => a.gateways.favorite);
  _registerGateway<SourceReaderGateway>(services, (a) => a.gateways.reader);
  _registerGateway<SourceSettingsGateway>(
    services,
    (a) => a.gateways.settingsGateway,
  );
  _registerGateway<SourceAccountGateway>(
    services,
    (a) => a.gateways.accountGateway,
  );
  _registerGateway<SourceDebugGateway>(
    services,
    (a) => a.gateways.debugGateway,
  );
  _registerGateway<SourceImageGateway>(
    services,
    (a) => a.gateways.imageGateway,
  );
  _registerGateway<SourceRecommendationGateway>(
    services,
    (a) => a.gateways.recommendation,
  );
  _registerGateway<SourceDailyRecommendationGateway>(
    services,
    (a) => a.gateways.dailyRecommendation,
  );
  _registerGateway<SourceSyncGateway>(services, (a) => a.gateways.sync);
  _registerGateway<SourceRuntimeGateway>(
    services,
    (a) => a.gateways.runtimeGateway,
  );
  _registerGateway<SourceSelectionGateway>(
    services,
    (a) => a.gateways.selection,
  );
  _registerGateway<SourceHomeGateway>(services, (a) => a.gateways.home);
  _registerGateway<SourceSwitchGateway>(
    services,
    (a) => a.gateways.switchGateway,
  );
  _registerGateway<SourceAdvancedGateway>(services, (a) => a.gateways.advanced);
  _registerGateway<SourceCategoryGateway>(services, (a) => a.gateways.category);
  _registerGateway<SourceCommentsGateway>(
    services,
    (a) => a.gateways.commentsGateway,
  );
  _registerGateway<SourceComicDetailGateway>(
    services,
    (a) => a.gateways.comicDetail,
  );
  _registerGateway<SourceBootstrapGateway>(
    services,
    (a) => a.gateways.bootstrap,
  );
  _registerGateway<SourceUpdateGateway>(services, (a) => a.gateways.update);
  _registerGateway<SourceScriptGateway>(services, (a) => a.gateways.script);
  _registerGateway<SourceLocalizationGateway>(
    services,
    (a) => a.gateways.localizationGateway,
  );
}

void _registerGateway<T extends Object>(
  GetIt services,
  T Function(SourceRuntimeAssembly assembly) select,
) {
  if (services.isRegistered<T>()) return;
  services.registerLazySingleton<T>(
    () => select(services<SourceRuntimeAssembly>()),
  );
}
