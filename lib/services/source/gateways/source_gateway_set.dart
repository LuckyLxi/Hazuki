import '../account/source_account_operations.dart';
import '../adapters/hazuki_source_content_adapters.dart';
import '../adapters/hazuki_source_image_adapters.dart';
import '../adapters/hazuki_source_runtime_adapters.dart';
import '../comments/comments_capability.dart';
import '../content/source_content_operations.dart';
import '../debug/source_debug_operations.dart';
import '../favorites/source_favorites_operations.dart';
import '../image/source_image_operations.dart';
import '../image/source_image_preparation_capability.dart';
import '../runtime/source_localization_operations.dart';
import '../runtime/source_runtime_diagnostics_operations.dart';
import '../runtime/source_runtime_initialization_operations.dart';
import '../runtime/source_runtime_recovery_operations.dart';
import '../runtime/source_script_editing_operations.dart';
import '../runtime/source_update_operations.dart';
import '../runtime/source_runtime_view.dart';
import '../runtime/source_settings_operations.dart';
import 'source_content_gateways.dart';
import 'source_image_gateways.dart';
import 'source_runtime_gateways.dart';
import 'source_task_control_gateway.dart';

/// Complete set of focused gateways created by the source composition root.
///
/// Keeping construction here prevents application setup from knowing Adapter
/// constructors or runtime implementation details.
class SourceGatewaySet {
  SourceGatewaySet({
    required this.taskControl,
    required SourceRuntimeView runtime,
    required SourceRuntimeInitializationOperations initialization,
    required SourceRuntimeDiagnosticsOperations diagnostics,
    required SourceScriptEditingOperations scriptEditing,
    required SourceUpdateOperations updates,
    required SourceRuntimeRecoveryOperations recovery,
    required SourceLocalizationOperations localization,
    required SourceSettingsOperations settings,
    required SourceAccountOperations account,
    required SourceCommentsCapability comments,
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
      initialization: initialization,
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
    final imageAdapter = HazukiSourceImageAdapter(
      runtime: runtime,
      image: image,
      diagnostics: diagnostics,
      debug: debug,
    );
    imageGateway = imageAdapter;
    debugGateway = imageAdapter;
    recommendation = imageAdapter;
    dailyRecommendation = HazukiSourceDailyRecommendationAdapter(
      runtime: runtime,
      image: image,
      content: content,
    );
    final runtimeAdapter = HazukiSourceRuntimeAdapter(
      runtime: runtime,
      initialization: initialization,
      scriptEditing: scriptEditing,
      updates: updates,
      recovery: recovery,
      account: account,
      favorites: favorites,
    );
    accountGateway = runtimeAdapter;
    runtimeGateway = runtimeAdapter;
    home = runtimeAdapter;
    script = runtimeAdapter;
    category = HazukiSourceCategoryAdapter(content: content, debug: debug);
    commentsGateway = HazukiSourceCommentsAdapter(
      comments: comments,
      account: account,
      debug: debug,
    );
    comicDetail = HazukiSourceComicDetailAdapter(
      runtime: runtime,
      account: account,
      favorites: favorites,
      content: content,
      image: image,
    );
    localizationGateway = localization;
  }

  late final SourceSearchGateway search;
  final SourceTaskControlGateway taskControl;
  late final SourceDiscoverGateway discover;
  late final SourceFavoriteGateway favorite;
  late final SourceReaderGateway reader;
  late final SourceSettingsGateway settingsGateway;
  late final SourceAccountGateway accountGateway;
  late final SourceDebugGateway debugGateway;
  late final SourceImageGateway imageGateway;
  late final SourceRecommendationGateway recommendation;
  late final SourceDailyRecommendationGateway dailyRecommendation;
  late final SourceRuntimeGateway runtimeGateway;
  late final SourceHomeGateway home;
  late final SourceCategoryGateway category;
  late final SourceCommentsGateway commentsGateway;
  late final SourceComicDetailGateway comicDetail;
  late final SourceScriptGateway script;
  late final SourceLocalizationGateway localizationGateway;
}
