import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:hazuki/app/app.dart';
import 'package:hazuki/features/home/support/home_feature_contracts.dart';
import 'package:hazuki/features/home/view/home_drawer.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/shared/navigation_tags.dart';
import 'package:hazuki/shared/windows/windows_comic_detail.dart';

class HomeNavigationActions {
  const HomeNavigationActions({
    required this.context,
    required this.scaffoldKey,
    required this.drawerTransitionContentBuilder,
    required this.appearanceSettings,
    required this.onAppearanceChanged,
    required this.locale,
    required this.onLocaleChanged,
    required this.featureEntrypoints,
    required this.useLegacyRankingSection,
    required this.comicDetailPageBuilder,
    required this.downloadsReaderPageBuilder,
  });

  final BuildContext context;
  final GlobalKey<ScaffoldState> scaffoldKey;
  final Widget Function() drawerTransitionContentBuilder;
  final AppearanceSettingsData appearanceSettings;
  final AppearanceSettingsApplyCallback onAppearanceChanged;
  final Locale? locale;
  final Future<void> Function(Locale? locale) onLocaleChanged;
  final HomeFeatureEntrypoints featureEntrypoints;
  final bool useLegacyRankingSection;
  final ComicDetailPageBuilder comicDetailPageBuilder;
  final HomeDownloadedComicReaderPageBuilder downloadsReaderPageBuilder;

  Widget buildComicDetailPage(ExploreComic comic, String heroTag) {
    return comicDetailPageBuilder(comic, heroTag);
  }

  Future<void> openFavoriteDetail(ExploreComic comic, String heroTag) {
    return openComicDetail(
      context,
      comic: comic,
      heroTag: heroTag,
      pageBuilder: buildComicDetailPage,
    );
  }

  Widget buildSearchPage({String? initialKeyword}) {
    return featureEntrypoints.buildSearchPage(
      initialKeyword: initialKeyword,
      autoFocusOnOpen: initialKeyword == null,
      comicDetailPageBuilder: buildComicDetailPage,
    );
  }

  Future<void> openSearch() async {
    final sourceRoute = ModalRoute.of(context);
    await featureEntrypoints.prepareSearchPage?.call();
    if (!context.mounted || sourceRoute == null || !sourceRoute.isCurrent) {
      return;
    }
    await Navigator.of(context).push(
      featureEntrypoints.buildSearchRoute<void>(
        builder: (_) => buildSearchPage(),
      ),
    );
  }

  Future<void> openHistory() async {
    await _openDrawerDestination(
      hideComicDetailPanel: true,
      (_) => featureEntrypoints.buildHistoryPage(
        comicDetailPageBuilder: buildComicDetailPage,
        onFavoriteRequested: featureEntrypoints.onHistoryFavoriteRequested,
      ),
    );
  }

  Future<void> openCategories() async {
    await _openDrawerDestination(
      hideComicDetailPanel: true,
      (_) => featureEntrypoints.buildCategoriesPage(
        searchPageBuilder: featureEntrypoints.buildSearchPage,
        comicDetailPageBuilder: buildComicDetailPage,
      ),
    );
  }

  Future<void> openRanking() async {
    await _openDrawerDestination(
      hideComicDetailPanel: true,
      (_) => featureEntrypoints.buildRankingPage(
        useLegacyRankingSection: useLegacyRankingSection,
        legacyRankingTitle: l10n(context).rankingTitle,
        comicDetailPageBuilder: buildComicDetailPage,
      ),
    );
  }

  Future<void> openDownloads() async {
    await _openDrawerDestination(
      hideComicDetailPanel: true,
      (_) => featureEntrypoints.buildDownloadsPage(
        readerPageBuilder: downloadsReaderPageBuilder,
      ),
    );
  }

  Future<void> openDownloadsWithDefaultTransition() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => featureEntrypoints.buildDownloadsPage(
          readerPageBuilder: downloadsReaderPageBuilder,
        ),
      ),
    );
  }

  Future<void> openSettings() async {
    await _openDrawerDestination(
      hideComicDetailPanel: true,
      (_) => featureEntrypoints.buildSettingsPage(
        appearanceSettings: appearanceSettings,
        onAppearanceChanged: onAppearanceChanged,
        locale: locale,
        onLocaleChanged: onLocaleChanged,
      ),
    );
  }

  Future<void> openLines() async {
    await _openDrawerDestination(
      hideComicDetailPanel: true,
      featureEntrypoints.buildLinesPage,
    );
  }

  Future<void> _openDrawerDestination(
    WidgetBuilder builder, {
    bool hideComicDetailPanel = false,
  }) async {
    final navigator = Navigator.of(context);
    if (!navigator.mounted) {
      return;
    }
    final drawerWidth = Platform.isWindows
        ? resolveHomeWindowsSidebarWidth(context)
        : resolveHomeDrawerWidth(context);
    final drawerColor =
        DrawerTheme.of(context).backgroundColor ??
        Theme.of(context).drawerTheme.backgroundColor ??
        Theme.of(context).colorScheme.surface;

    final route = _DrawerExpandPageRoute<void>(
      builder: builder,
      drawerWidth: drawerWidth,
      drawerColor: drawerColor,
      drawerContent: drawerTransitionContentBuilder(),
      reservedTrailingWidthFactor: 0,
    );

    scaffoldKey.currentState?.closeDrawer();
    final controller = WindowsComicDetailController.instance;
    if (hideComicDetailPanel && useWindowsComicDetailPanel) {
      final hideToken = controller.beginTemporaryHide();
      route.onPopStarted = () {
        controller.endTemporaryHide(hideToken);
      };
      try {
        await navigator.push<void>(route);
      } finally {
        controller.endTemporaryHide(hideToken);
      }
      return;
    }

    await navigator.push<void>(route);
  }
}

class _DrawerExpandPageRoute<T> extends MaterialPageRoute<T> {
  _DrawerExpandPageRoute({
    required super.builder,
    required this.drawerWidth,
    required this.drawerColor,
    required this.drawerContent,
    required this.reservedTrailingWidthFactor,
  });

  final double drawerWidth;
  final Color drawerColor;
  final Widget drawerContent;
  final double reservedTrailingWidthFactor;
  VoidCallback? onPopStarted;

  bool get _preserveTrailingPanel => reservedTrailingWidthFactor > 0;

  @override
  bool get opaque => !_preserveTrailingPanel;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 460);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 300);

  @override
  bool didPop(T? result) {
    onPopStarted?.call();
    onPopStarted = null;
    return super.didPop(result);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (!_preserveTrailingPanel &&
        animation.status != AnimationStatus.forward) {
      return super.buildTransitions(
        context,
        animation,
        secondaryAnimation,
        child,
      );
    }
    if (animation.isCompleted) {
      return child;
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final reservedTrailingWidth = screenWidth * reservedTrailingWidthFactor;
    final targetContentWidth = (screenWidth - reservedTrailingWidth).clamp(
      drawerWidth,
      screenWidth,
    );
    final expandCurve = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final drawerFadeCurve = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.0, 0.32, curve: Curves.easeOutCubic),
      reverseCurve: const Interval(0.0, 0.32, curve: Curves.easeInCubic),
    );
    final pageFadeCurve = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.22, 0.88, curve: Curves.easeOutCubic),
      reverseCurve: const Interval(0.12, 0.78, curve: Curves.easeInCubic),
    );
    final pageSlideCurve = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.18, 1.0, curve: Curves.easeOutCubic),
      reverseCurve: const Interval(0.0, 0.82, curve: Curves.easeInCubic),
    );

    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, pageChild) {
        final width = Tween<double>(
          begin: drawerWidth,
          end: targetContentWidth,
        ).evaluate(expandCurve);
        final revealFactor = targetContentWidth <= 0
            ? 1.0
            : (width / targetContentWidth).clamp(0.0, 1.0);
        final drawerOpacity = (1.0 - drawerFadeCurve.value).clamp(0.0, 1.0);
        final drawerOffset = Tween<double>(
          begin: 0,
          end: -28,
        ).evaluate(drawerFadeCurve);

        final statusBarHeight = MediaQuery.paddingOf(context).top;
        final statusBarIconBrightness =
            ThemeData.estimateBrightnessForColor(drawerColor) == Brightness.dark
            ? Brightness.light
            : Brightness.dark;
        final statusBarOverlayStyle = SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: statusBarIconBrightness,
          statusBarBrightness: statusBarIconBrightness == Brightness.light
              ? Brightness.dark
              : Brightness.light,
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: width,
                child: Material(
                  color: drawerColor,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      IgnorePointer(
                        child: Opacity(
                          opacity: drawerOpacity,
                          child: Transform.translate(
                            offset: Offset(drawerOffset, 0),
                            child: drawerContent,
                          ),
                        ),
                      ),
                      ClipRect(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          widthFactor: revealFactor,
                          child: SizedBox(
                            width: screenWidth,
                            child: FadeTransition(
                              opacity: pageFadeCurve,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0.035, 0),
                                  end: Offset.zero,
                                ).animate(pageSlideCurve),
                                child: pageChild,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (statusBarHeight > 0)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: statusBarHeight,
                child: AnnotatedRegion<SystemUiOverlayStyle>(
                  value: statusBarOverlayStyle,
                  child: const IgnorePointer(child: SizedBox.expand()),
                ),
              ),
          ],
        );
      },
    );
  }
}
