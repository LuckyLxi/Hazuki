import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../models/hazuki_models.dart';
import '../comic_detail_page.dart';
import '../downloads_page.dart';
import '../history_page.dart';
import '../ranking_page.dart';
import '../reader_page.dart';
import '../search/search.dart';
import '../settings/settings.dart';
import '../tag_category_page.dart';
import 'home_drawer.dart';

class HomeNavigationActions {
  const HomeNavigationActions({
    required this.context,
    required this.scaffoldKey,
    required this.drawerTransitionContent,
    required this.appearanceSettings,
    required this.onAppearanceChanged,
    required this.locale,
    required this.onLocaleChanged,
  });

  final BuildContext context;
  final GlobalKey<ScaffoldState> scaffoldKey;
  final Widget drawerTransitionContent;
  final AppearanceSettingsData appearanceSettings;
  final AppearanceSettingsApplyCallback onAppearanceChanged;
  final Locale? locale;
  final Future<void> Function(Locale? locale) onLocaleChanged;

  Widget buildComicDetailPage(ExploreComic comic, String heroTag) {
    return ComicDetailPage(comic: comic, heroTag: heroTag);
  }

  Future<void> openFavoriteDetail(ExploreComic comic, String heroTag) {
    return openComicDetail(
      context,
      comic: comic,
      heroTag: heroTag,
      pageBuilder: buildComicDetailPage,
    );
  }

  SearchPage buildSearchPage({String? initialKeyword}) {
    return SearchPage(
      initialKeyword: initialKeyword,
      comicDetailPageBuilder: buildComicDetailPage,
    );
  }

  Future<void> openSearch() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => buildSearchPage()));
  }

  Future<void> openHistory() async {
    await _openDrawerDestination(
      (_) => HistoryPage(comicDetailPageBuilder: buildComicDetailPage),
    );
  }

  Future<void> openCategories() async {
    await _openDrawerDestination(
      hideComicDetailPanel: true,
      (_) => TagCategoryPage(
        searchPageBuilder: (tag) => buildSearchPage(initialKeyword: tag),
      ),
    );
  }

  Future<void> openRanking() async {
    await _openDrawerDestination(
      (_) => RankingPage(comicDetailPageBuilder: buildComicDetailPage),
    );
  }

  Future<void> openDownloads() async {
    await _openDrawerDestination(
      (_) => DownloadsPage(
        readerPageBuilder: (comic, chapter) => ReaderPage(
          title: comic.title,
          chapterTitle: resolveHazukiChapterTitle(context, chapter.title),
          comicId: comic.comicId,
          epId: chapter.epId,
          chapterIndex: chapter.index,
          images: chapter.imagePaths,
        ),
      ),
    );
  }

  Future<void> openSettings() async {
    await _openDrawerDestination(
      hideComicDetailPanel: true,
      (_) => SettingsPage(
        appearanceSettings: appearanceSettings,
        onAppearanceChanged: onAppearanceChanged,
        locale: locale,
        onLocaleChanged: onLocaleChanged,
        cloudSyncPageBuilder: (_) => const CloudSyncPage(),
        labSettingsPageBuilder: (_) => const LabSettingsPage(),
        advancedSettingsPageBuilder: (_) => AdvancedSettingsPage(
          logsPageBuilder: (_) => const LogsPage(),
          comicSourceEditorPageBuilder: (_) => const ComicSourceEditorPage(),
          restoreComicSource: showComicSourceRestoreDialog,
        ),
      ),
    );
  }

  Future<void> openLines() async {
    await _openDrawerDestination(
      hideComicDetailPanel: true,
      (_) => const LineSettingsPage(),
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
    final drawerWidth = resolveHomeDrawerWidth(context);
    final drawerColor =
        DrawerTheme.of(context).backgroundColor ??
        Theme.of(context).drawerTheme.backgroundColor ??
        Theme.of(context).colorScheme.surface;
    final preserveComicDetailPanel =
        useWindowsComicDetailPanel &&
        !hideComicDetailPanel &&
        WindowsComicDetailController.instance.isPanelVisible;

    final route = _DrawerExpandPageRoute<void>(
      builder: builder,
      drawerWidth: drawerWidth,
      drawerColor: drawerColor,
      drawerContent: drawerTransitionContent,
      reservedTrailingWidthFactor: preserveComicDetailPanel ? 0.6 : 0,
    );

    scaffoldKey.currentState?.closeDrawer();
    final controller = WindowsComicDetailController.instance;
    if (hideComicDetailPanel && useWindowsComicDetailPanel) {
      await controller.hideWhile(() => navigator.push<void>(route));
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

  bool get _preserveTrailingPanel => reservedTrailingWidthFactor > 0;

  @override
  bool get opaque => !_preserveTrailingPanel;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 460);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 300);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (!_preserveTrailingPanel && animation.status != AnimationStatus.forward) {
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
                            child: SafeArea(child: drawerContent),
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
          ],
        );
      },
    );
  }
}
