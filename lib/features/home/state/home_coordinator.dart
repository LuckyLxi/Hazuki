import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'package:hazuki/features/favorite/favorite.dart';
import 'package:hazuki/services/discover_daily_recommendation_service.dart';
import 'package:hazuki/services/hazuki_source_service.dart';
import 'package:hazuki/features/home/state/home_profile_controller.dart';
import 'package:hazuki/features/home/support/home_profile_flow.dart';
import 'package:hazuki/features/home/state/home_shell_controller.dart';

class HomeCoordinator extends ChangeNotifier {
  HomeCoordinator({
    required int initialTabIndex,
    required HazukiSourceService sourceService,
    required DiscoverDailyRecommendationService dailyRecommendationService,
  }) : _sourceService = sourceService,
       _dailyRecommendationService = dailyRecommendationService,
       _profileController = HomeProfileController(sourceService: sourceService),
       _shellController = HomeShellController(initialTabIndex: initialTabIndex),
       scaffoldKey = GlobalKey<ScaffoldState>(),
       favoriteActionsBinding = FavoritePageActionsBinding() {
    _profileController.addListener(_relayChange);
    _shellController.addListener(_relayChange);
    _dailyRecommendationService.addListener(_relayChange);
    _sourceService.addListener(_relayChange);
  }

  static const MethodChannel _mediaChannel = MethodChannel(
    'hazuki.comics/media',
  );

  final HazukiSourceService _sourceService;
  final HomeProfileController _profileController;
  final HomeShellController _shellController;
  final DiscoverDailyRecommendationService _dailyRecommendationService;
  final GlobalKey<ScaffoldState> scaffoldKey;
  final FavoritePageActionsBinding favoriteActionsBinding;
  bool _disposed = false;

  String? get avatarUrl => _profileController.avatarUrl;
  String get username => _profileController.username;
  bool get autoCheckInEnabled => _profileController.autoCheckInEnabled;
  bool get checkInBusy => _profileController.checkInBusy;
  bool get checkedInToday => _profileController.checkedInToday;
  int get authVersion => _profileController.authVersion;
  bool get isLogged => _profileController.isLogged;

  int get currentIndex => _shellController.currentIndex;
  double get discoverSearchMorphProgress =>
      _shellController.discoverSearchMorphProgress;
  FavoriteAppBarActionsState get favoriteAppBarActions =>
      _shellController.favoriteAppBarActions;
  DiscoverDailyRecommendationState get dailyRecommendationState =>
      _dailyRecommendationService.state;

  void start(BuildContext context) {
    unawaited(syncUserProfile(context));
    unawaited(loadFirstUseText(context));
    unawaited(loadOtherSettings(context));
    unawaited(_prewarmSourceRuntime(context));
    if (_sourceService.isLogged) {
      unawaited(_sourceService.warmUpFavoritesDebugInfo());
    }
  }

  void handleWidgetUpdate(
    BuildContext context, {
    required Locale? oldLocale,
    required Locale? newLocale,
    required int oldRefreshTick,
    required int newRefreshTick,
  }) {
    final oldLocaleCode = oldLocale?.languageCode;
    final newLocaleCode = newLocale?.languageCode;
    if (oldLocaleCode != newLocaleCode) {
      unawaited(loadFirstUseText(context));
      unawaited(syncUserProfile(context));
    }
    if (oldRefreshTick != newRefreshTick) {
      unawaited(syncUserProfile(context));
      unawaited(loadOtherSettings(context));
    }
  }

  Future<void> syncUserProfile(BuildContext context) async {
    await _profileController.syncUserProfile(context);
  }

  Future<void> loadFirstUseText(BuildContext context) async {
    await _profileController.loadFirstUseText(context);
  }

  Future<void> loadOtherSettings(BuildContext context) async {
    await _profileController.loadOtherSettings(context);
    final enabled = await _dailyRecommendationService.loadEnabled();
    await _dailyRecommendationService.ensurePrepared(enabled: enabled);
    _relayChange();
  }

  Future<void> performCheckIn(
    BuildContext context, {
    required bool triggeredAutomatically,
  }) async {
    await _profileController.performCheckIn(
      context,
      triggeredAutomatically: triggeredAutomatically,
    );
  }

  Future<bool> handleWillPop(BuildContext context) {
    return _shellController.handleWillPop(
      context: context,
      scaffoldKey: scaffoldKey,
    );
  }

  Future<void> handleDestinationSelected(int index) async {
    if (currentIndex == index) {
      return;
    }

    await _shellController.handleDestinationSelected(index);
  }

  Future<void> changeFavoriteSortOrder(String order) {
    return favoriteActionsBinding.changeSortOrder(order);
  }

  Future<void> createFavoriteFolder() {
    return favoriteActionsBinding.createFolder();
  }

  Future<void> toggleFavoriteMode() {
    return favoriteActionsBinding.toggleMode();
  }

  void handleDiscoverSearchMorphProgressChanged(double progress) {
    _shellController.handleDiscoverSearchMorphProgressChanged(progress);
  }

  void handleFavoriteAppBarActionsChanged(FavoriteAppBarActionsState state) {
    _shellController.handleFavoriteAppBarActionsChanged(state);
  }

  HomeProfileFlow createProfileFlow(
    BuildContext context, {
    required bool Function() isMounted,
  }) {
    return HomeProfileFlow(
      context: context,
      isMounted: isMounted,
      profileController: _profileController,
      sourceService: _sourceService,
      mediaChannel: _mediaChannel,
      syncUserProfile: () => syncUserProfile(context),
    );
  }

  void _relayChange() {
    if (_disposed) return;

    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }

  Future<void> _prewarmSourceRuntime(BuildContext context) async {
    await _sourceService.prewarmInBackground();
    if (!context.mounted) {
      return;
    }
    await syncUserProfile(context);
    if (_sourceService.isLogged) {
      unawaited(_sourceService.warmUpFavoritesDebugInfo());
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _dailyRecommendationService.removeListener(_relayChange);
    _sourceService.removeListener(_relayChange);
    _profileController
      ..removeListener(_relayChange)
      ..dispose();
    _shellController
      ..removeListener(_relayChange)
      ..dispose();
    super.dispose();
  }
}
