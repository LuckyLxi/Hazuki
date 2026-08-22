import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:hazuki/app/app.dart';
import 'package:hazuki/features/home/home.dart';
import 'package:hazuki/shared/source_account/source_account_actions.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/shared/windows/windows_comic_detail.dart';
import 'package:hazuki/shared/chapter_title_resolver.dart';
import 'package:hazuki/shared/reading/reader_offline_chapter_data.dart';

class HazukiHomePage extends StatefulWidget {
  const HazukiHomePage({
    super.key,
    this.initialTabIndex = 0,
    required this.appearanceSettings,
    required this.onAppearanceChanged,
    required this.locale,
    required this.onLocaleChanged,
    required this.featureEntrypoints,
    required this.services,
    this.allowDiscoverInitialLoad = true,
    this.hideDiscoverLoadingUntilAllowed = false,
    this.refreshTick = 0,
  });

  final int initialTabIndex;
  final AppearanceSettingsData appearanceSettings;
  final AppearanceSettingsApplyCallback onAppearanceChanged;
  final Locale? locale;
  final Future<void> Function(Locale? locale) onLocaleChanged;
  final HomeFeatureEntrypoints featureEntrypoints;
  final HomeServices services;
  final bool allowDiscoverInitialLoad;
  final bool hideDiscoverLoadingUntilAllowed;
  final int refreshTick;

  @override
  State<HazukiHomePage> createState() => _HazukiHomePageState();
}

class _HazukiHomePageState extends State<HazukiHomePage> {
  late final HomeCoordinator _coordinator;
  HomeDrawerDestination? _selectedDrawerDestination;

  Widget _buildComicDetailPage(
    ExploreComic comic,
    String heroTag, {
    bool isDesktopPanel = false,
    bool? shouldAnimateInitialRevealOverride,
    VoidCallback? onCloseRequested,
  }) {
    return widget.featureEntrypoints.buildComicDetailPage(
      comic,
      heroTag,
      isDesktopPanel: isDesktopPanel,
      shouldAnimateInitialRevealOverride: shouldAnimateInitialRevealOverride,
      onCloseRequested: onCloseRequested,
    );
  }

  @override
  void initState() {
    super.initState();
    _coordinator = HomeCoordinator(
      initialTabIndex: widget.initialTabIndex,
      sourceService: widget.services.sourceService,
      sourceSwitchService: widget.services.sourceSwitchService,
      imageService: widget.services.imageService,
      dailyRecommendationService: widget.services.dailyRecommendationService,
    );
    _coordinator.start(context);
    WindowsComicDetailController.instance.panelBuilder =
        (
          comic,
          heroTag, {
          required shouldAnimatePanelReveal,
          required onCloseRequested,
        }) => _buildComicDetailPage(
          comic,
          heroTag,
          isDesktopPanel: true,
          shouldAnimateInitialRevealOverride: shouldAnimatePanelReveal,
          onCloseRequested: onCloseRequested,
        );
  }

  @override
  void dispose() {
    WindowsComicDetailController.instance.panelBuilder = null;
    _coordinator.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HazukiHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _coordinator.handleWidgetUpdate(
      context,
      oldLocale: oldWidget.locale,
      newLocale: widget.locale,
      oldRefreshTick: oldWidget.refreshTick,
      newRefreshTick: widget.refreshTick,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _coordinator,
      builder: (context, _) {
        final isLogged = _coordinator.isLogged;
        final profileLoading = _coordinator.profileLoading;
        final sidebarProfile = HomeSidebarProfileState(
          isLogged: _coordinator.isLogged,
          profileLoading: profileLoading,
          avatarUrl: _coordinator.avatarUrl,
          username: _coordinator.username,
          autoCheckInEnabled: _coordinator.autoCheckInEnabled,
          showCheckInActions: _coordinator.isCheckInAvailable,
          checkInBusy: _coordinator.checkInBusy,
          checkedInToday: _coordinator.checkedInToday,
        );
        final profileFlow = _coordinator.createProfileFlow(
          context,
          isMounted: () => mounted,
        );
        final navigation = HomeNavigationActions(
          context: context,
          scaffoldKey: _coordinator.scaffoldKey,
          drawerTransitionContentBuilder: () => Platform.isWindows
              ? HomeWindowsSidebar(
                  profile: sidebarProfile,
                  actions: const HomeSidebarActions(),
                  currentIndex: _coordinator.currentIndex,
                  selectedDestination: _selectedDrawerDestination,
                )
              : HomeDrawerContent(
                  profile: sidebarProfile,
                  actions: const HomeSidebarActions(),
                  activeSourceKey: _coordinator.sourceService.activeSourceKey,
                  selectedDestination: _selectedDrawerDestination,
                ),
          appearanceSettings: widget.appearanceSettings,
          onAppearanceChanged: widget.onAppearanceChanged,
          locale: widget.locale,
          onLocaleChanged: widget.onLocaleChanged,
          featureEntrypoints: widget.featureEntrypoints,
          useLegacyRankingSection:
              _coordinator.sourceService.isActiveCopyMangaSource,
          comicDetailPageBuilder: (comic, heroTag) =>
              _buildComicDetailPage(comic, heroTag),
          downloadsReaderPageBuilder: (comic, chapter) =>
              widget.featureEntrypoints.buildReaderPage(
                title: comic.title,
                chapterTitle: resolveHazukiChapterTitle(context, chapter.title),
                comicId: comic.comicId,
                epId: chapter.epId,
                chapterIndex: chapter.index,
                images: chapter.imagePaths,
                sourceKey: comic.sourceKey,
                coverUrl: comic.coverUrl,
                offlineMode: true,
                offlineChapters: [
                  for (final downloadedChapter in comic.chapters)
                    ReaderOfflineChapterData(
                      epId: downloadedChapter.epId,
                      title: resolveHazukiChapterTitle(
                        context,
                        downloadedChapter.title,
                      ),
                      index: downloadedChapter.index,
                      images: downloadedChapter.imagePaths,
                    ),
                ],
              ),
        );

        final discoverChild = widget.featureEntrypoints.buildDiscoverTab(
          comicDetailPageBuilder: navigation.buildComicDetailPage,
          dailyRecommendationState: _coordinator.dailyRecommendationState,
          allowInitialLoad: widget.allowDiscoverInitialLoad,
          hideLoadingUntilInitialLoadAllowed:
              widget.hideDiscoverLoadingUntilAllowed,
          onSearchMorphProgressChanged:
              _coordinator.handleDiscoverSearchMorphProgressChanged,
          onSearchTap: () {
            unawaited(navigation.openSearch());
          },
          onRequestLogin: profileFlow.showLoginDialog,
        );
        final favoriteChild = widget.featureEntrypoints.buildFavoriteTab(
          actionsBinding: _coordinator.favoriteActionsBinding,
          authVersion: _coordinator.authVersion,
          onAppBarActionsChanged:
              _coordinator.handleFavoriteAppBarActionsChanged,
          onRequestLogin: profileFlow.showLoginDialog,
          onComicTap: navigation.openFavoriteDetail,
        );

        return HomeScaffoldShell(
          scaffoldKey: _coordinator.scaffoldKey,
          currentIndex: _coordinator.currentIndex,
          discoverSearchMorphProgress: _coordinator.discoverSearchMorphProgress,
          usePinnedDiscoverSearch:
              _coordinator.dailyRecommendationState.hasRecommendations,
          downloadStatus: widget.services.downloadStatus,
          activeSourceKey: _coordinator.sourceService.activeSourceKey,
          supportsSourceAccount:
              _coordinator.sourceService.sourceMeta?.supportsAccount == true,
          discoverChild: discoverChild,
          favoriteChild: favoriteChild,
          favoriteAppBarActions: _coordinator.favoriteAppBarActions,
          showFavoriteBackToTop: _coordinator.favoriteBackToTopVisible,
          isLogged: isLogged,
          profileLoading: profileLoading,
          avatarUrl: _coordinator.avatarUrl,
          username: _coordinator.username,
          autoCheckInEnabled: _coordinator.autoCheckInEnabled,
          showCheckInActions: _coordinator.isCheckInAvailable,
          checkInBusy: _coordinator.checkInBusy,
          checkedInToday: _coordinator.checkedInToday,
          onWillPop: () => _coordinator.handleWillPop(context),
          onExitRequested: SystemNavigator.pop,
          onOpenSearch: () {
            unawaited(navigation.openSearch());
          },
          onFavoriteSortSelected: (order) {
            unawaited(_coordinator.changeFavoriteSortOrder(order));
          },
          onFavoriteCreateFolderPressed: () {
            unawaited(_coordinator.createFavoriteFolder());
          },
          onFavoriteModeTogglePressed: () {
            unawaited(_coordinator.toggleFavoriteMode());
          },
          onFavoriteBackToTopPressed: () {
            unawaited(_coordinator.scrollFavoriteToTop());
          },
          onProfileTap: () {
            if (profileLoading) {
              return;
            }
            if (isLogged) {
              unawaited(profileFlow.showAvatarCard());
            } else {
              unawaited(profileFlow.showLoginDialog());
            }
          },
          onCheckInPressed: () {
            unawaited(
              _coordinator.performCheckIn(
                context,
                triggeredAutomatically: false,
              ),
            );
          },
          onSwitchSourcePressed: () {
            unawaited(() async {
              await showHomeSourceSwitchDialog(
                context,
                sourceService: _coordinator.sourceSwitchService,
                onSourceSwitched: () => _coordinator.syncUserProfile(context),
              );
              if (!mounted) {
                return;
              }
              setState(() {});
            }());
          },
          onOpenHistory: () {
            setState(() {
              _selectedDrawerDestination = HomeDrawerDestination.history;
            });
            unawaited(navigation.openHistory());
          },
          onOpenCategories: () {
            setState(() {
              _selectedDrawerDestination = HomeDrawerDestination.categories;
            });
            unawaited(navigation.openCategories());
          },
          onOpenRanking: () {
            setState(() {
              _selectedDrawerDestination = HomeDrawerDestination.ranking;
            });
            unawaited(navigation.openRanking());
          },
          onOpenDownloads: () {
            setState(() {
              _selectedDrawerDestination = HomeDrawerDestination.downloads;
            });
            unawaited(navigation.openDownloads());
          },
          onOpenDownloadTasks: () {
            unawaited(navigation.openDownloadsWithDefaultTransition());
          },
          onOpenSettings: () {
            setState(() {
              _selectedDrawerDestination = HomeDrawerDestination.settings;
            });
            unawaited(() async {
              await navigation.openSettings();
              if (!context.mounted) {
                return;
              }
              await _coordinator.loadOtherSettings(context);
            }());
          },
          onOpenLines: () {
            setState(() {
              _selectedDrawerDestination = HomeDrawerDestination.lines;
            });
            unawaited(navigation.openLines());
          },
          selectedDrawerDestination: _selectedDrawerDestination,
          onDestinationSelected: (index) {
            setState(() {
              _selectedDrawerDestination = null;
            });
            unawaited(_coordinator.handleDestinationSelected(index));
          },
        );
      },
    );
  }
}
