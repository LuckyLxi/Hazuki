import '../comic/comic_details_capability.dart';
import '../comic/comic_detail_tab_capability.dart';
import '../category/source_category_capability.dart';
import '../content/explore_capability.dart';
import '../account/account_session_capability.dart';
import '../account/source_daily_check_in_capability.dart';
import '../debug/debug_favorites_capability.dart';
import '../adapters/hazuki_source_content_adapters.dart';
import '../adapters/hazuki_source_image_adapters.dart';
import '../adapters/hazuki_source_runtime_adapters.dart';
import '../comments/comments_capability.dart';
import '../content/source_cloud_reading.dart';
import '../content/source_content_operations.dart';
import '../content/source_reading_progress_uploads.dart';
import '../debug/source_debug_operations.dart';
import '../favorites/source_favorites_capability.dart';
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
    required SourceAccountSessionCapability account,
    required SourceDailyCheckInCapability dailyCheckIn,
    required SourceCommentsCapability comments,
    required SourceContentOperations content,
    required SourceCloudReadingCapability cloudReading,
    required SourceReadingProgressUploads readingProgressUploads,
    required SourceComicDetailsCapability comicDetails,
    required SourceComicDetailTabCapability detailTabs,
    required SourceCategoryCapability category,
    required SourceExploreCapability explore,
    required SourceFavoritesCapability favorites,
    required SourceFavoritesDebugCapability favoritesDebug,
    required Stream<void> cloudFavoritesChangedStream,
    required SourceImageOperations image,
    required SourceImagePreparationCapability imagePreparation,
    required SourceDebugOperations debug,
  }) {
    search = HazukiSourceSearchAdapter(
      runtime: runtime,
      recovery: recovery,
      content: content,
      comicDetails: comicDetails,
    );
    discover = HazukiSourceDiscoverAdapter(
      runtime: runtime,
      recovery: recovery,
      explore: explore,
      category: category,
      account: account,
    );
    favorite = HazukiSourceFavoriteAdapter(
      runtime: runtime,
      recovery: recovery,
      account: account,
      favorites: favorites,
      cloudFavoritesChangedStream: cloudFavoritesChangedStream,
      initialization: initialization,
    );
    final readerAdapter = HazukiSourceReaderAdapter(
      readingProgressUploads: readingProgressUploads,
      comicDetails: comicDetails,
      imagePreparation: imagePreparation,
      image: image,
      debug: debug,
    );
    reader = readerAdapter;
    readerSessions = readerAdapter;
    downloadSessions = readerAdapter;
    this.readingProgressUploads = readerAdapter;
    this.cloudReading = cloudReading;
    cloudReadingEvents = cloudReading;
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
      recovery: recovery,
      image: image,
      content: content,
      comicDetails: comicDetails,
    );
    final runtimeAdapter = HazukiSourceRuntimeAdapter(
      runtime: runtime,
      initialization: initialization,
      scriptEditing: scriptEditing,
      updates: updates,
      recovery: recovery,
      account: account,
      dailyCheckIn: dailyCheckIn,
      favoritesDebug: favoritesDebug,
    );
    accountGateway = runtimeAdapter;
    runtimeGateway = runtimeAdapter;
    home = runtimeAdapter;
    script = runtimeAdapter;
    this.category = HazukiSourceCategoryAdapter(
      category: category,
      debug: debug,
    );
    commentsGateway = HazukiSourceCommentsAdapter(
      comments: comments,
      account: account,
      debug: debug,
    );
    comicDetail = HazukiSourceComicDetailAdapter(
      runtime: runtime,
      account: account,
      favorites: favorites,
      comicDetails: comicDetails,
      category: category,
      detailTabs: detailTabs,
      image: image,
    );
    localizationGateway = localization;
  }

  late final SourceSearchGateway search;
  final SourceTaskControlGateway taskControl;
  late final SourceDiscoverGateway discover;
  late final SourceFavoriteGateway favorite;
  late final SourceReaderGateway reader;
  late final SourceReaderSessionGateway readerSessions;
  late final SourceDownloadSessionGateway downloadSessions;
  late final SourceReadingProgressGateway readingProgressUploads;
  late final SourceCloudReadingGateway cloudReading;
  late final SourceCloudReadingEvents cloudReadingEvents;
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
