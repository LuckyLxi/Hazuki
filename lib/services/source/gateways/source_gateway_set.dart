import '../account/source_account_operations.dart';
import '../adapters/hazuki_source_content_adapters.dart';
import '../adapters/hazuki_source_image_adapters.dart';
import '../adapters/hazuki_source_runtime_adapters.dart';
import '../adapters/hazuki_source_sync_adapter.dart';
import '../comments/source_comments_operations.dart';
import '../content/source_content_operations.dart';
import '../debug/source_debug_operations.dart';
import '../favorites/source_favorites_operations.dart';
import '../image/source_image_operations.dart';
import '../image/source_image_preparation_capability.dart';
import '../runtime/source_localization_operations.dart';
import '../runtime/source_runtime_operations.dart';
import '../runtime/source_runtime_view.dart';
import '../runtime/source_settings_operations.dart';
import 'source_content_gateways.dart';
import 'source_image_gateways.dart';
import 'source_runtime_gateways.dart';
import 'source_sync_gateway.dart';

/// Complete set of focused gateways created by the source composition root.
///
/// Keeping construction here prevents application setup from knowing Adapter
/// constructors or runtime implementation details.
class SourceGatewaySet {
  SourceGatewaySet({
    required SourceRuntimeView runtime,
    required SourceRuntimeOperations runtimeOperations,
    required SourceLocalizationOperations localization,
    required SourceSettingsOperations settings,
    required SourceAccountOperations account,
    required SourceCommentsOperations comments,
    required SourceContentOperations content,
    required SourceFavoritesOperations favorites,
    required SourceImageOperations image,
    required SourceImagePreparationCapability imagePreparation,
    required SourceDebugOperations debug,
  }) {
    search = HazukiSourceSearchAdapter(runtime: runtime, content: content);
    discover = HazukiSourceDiscoverAdapter(
      runtime: runtime,
      content: content,
      account: account,
    );
    favorite = HazukiSourceFavoriteAdapter(
      runtime: runtime,
      account: account,
      favorites: favorites,
      runtimeOperations: runtimeOperations,
    );
    reader = HazukiSourceReaderAdapter(
      content: content,
      imagePreparation: imagePreparation,
      image: image,
      debug: debug,
    );
    settingsGateway = HazukiSourceSettingsAdapter(
      runtime: runtime,
      settings: settings,
      image: image,
    );
    accountGateway = HazukiSourceAccountAdapter(
      runtime: runtime,
      runtimeOperations: runtimeOperations,
      account: account,
    );
    debugGateway = HazukiSourceDebugAdapter(
      runtimeOperations: runtimeOperations,
      debug: debug,
    );
    imageGateway = HazukiSourceImageAdapter(runtime: runtime, image: image);
    recommendation = HazukiSourceRecommendationAdapter(
      runtime: runtime,
      image: image,
      runtimeOperations: runtimeOperations,
      debug: debug,
    );
    dailyRecommendation = HazukiSourceDailyRecommendationAdapter(
      runtime: runtime,
      image: image,
      content: content,
    );
    sync = HazukiSourceSyncAdapter(
      runtime: runtime,
      runtimeOperations: runtimeOperations,
    );
    final runtimeAdapter = HazukiSourceRuntimeAdapter(
      runtime: runtime,
      runtimeOperations: runtimeOperations,
      account: account,
      favorites: favorites,
      settings: settings,
    );
    runtimeGateway = runtimeAdapter;
    selection = runtimeAdapter;
    switchGateway = runtimeAdapter;
    home = HazukiSourceHomeAdapter(
      runtime: runtime,
      runtimeOperations: runtimeOperations,
      account: account,
      favorites: favorites,
    );
    advanced = HazukiSourceAdvancedAdapter(
      runtime: runtime,
      runtimeOperations: runtimeOperations,
      settings: settings,
    );
    category = HazukiSourceCategoryAdapter(content: content, debug: debug);
    commentsGateway = HazukiSourceCommentsAdapter(
      comments: comments,
      debug: debug,
    );
    comicDetail = HazukiSourceComicDetailAdapter(
      runtime: runtime,
      account: account,
      favorites: favorites,
      content: content,
      image: image,
    );
    bootstrap = HazukiSourceBootstrapAdapter(runtimeOperations);
    update = HazukiSourceUpdateAdapter(runtimeOperations);
    script = HazukiSourceScriptAdapter(runtimeOperations);
    localizationGateway = HazukiSourceLocalizationAdapter(localization);
  }

  late final SourceSearchGateway search;
  late final SourceDiscoverGateway discover;
  late final SourceFavoriteGateway favorite;
  late final SourceReaderGateway reader;
  late final SourceSettingsGateway settingsGateway;
  late final SourceAccountGateway accountGateway;
  late final SourceDebugGateway debugGateway;
  late final SourceImageGateway imageGateway;
  late final SourceRecommendationGateway recommendation;
  late final SourceDailyRecommendationGateway dailyRecommendation;
  late final SourceSyncGateway sync;
  late final SourceRuntimeGateway runtimeGateway;
  late final SourceSelectionGateway selection;
  late final SourceSwitchGateway switchGateway;
  late final SourceHomeGateway home;
  late final SourceAdvancedGateway advanced;
  late final SourceCategoryGateway category;
  late final SourceCommentsGateway commentsGateway;
  late final SourceComicDetailGateway comicDetail;
  late final SourceBootstrapGateway bootstrap;
  late final SourceUpdateGateway update;
  late final SourceScriptGateway script;
  late final SourceLocalizationGateway localizationGateway;
}
