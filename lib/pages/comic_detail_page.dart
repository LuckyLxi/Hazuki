import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/app.dart';
import '../l10n/l10n.dart';
import '../models/hazuki_models.dart';
import '../services/hazuki_source_service.dart';
import '../services/local_favorites_service.dart';
import '../services/manga_download_service.dart';
import '../widgets/widgets.dart';
import 'comments_page.dart';
import 'comic_detail/comic_detail.dart';
import 'reader_page.dart';
import 'search/search.dart';

part 'comic_detail/comic_detail_app_bar.dart';
part 'comic_detail/comic_detail_cover.dart';
part 'comic_detail/comic_detail_cover_actions.dart';
part 'comic_detail/comic_detail_favorite_actions.dart';
part 'comic_detail/comic_detail_header.dart';
part 'comic_detail/comic_detail_lifecycle_actions.dart';
part 'comic_detail/comic_detail_meta.dart';
part 'comic_detail/comic_detail_meta_section.dart';
part 'comic_detail/comic_detail_panels.dart';
part 'comic_detail/comic_detail_reader_actions.dart';
part 'comic_detail/comic_detail_runtime.dart';
part 'comic_detail/comic_detail_scaffold.dart';
part 'comic_detail/comic_detail_sections.dart';
part 'comic_detail/comic_detail_theme_support.dart';

class ComicDetailPage extends StatefulWidget {
  const ComicDetailPage({
    super.key,
    required this.comic,
    required this.heroTag,
    this.isDesktopPanel = false,
    this.shouldAnimateInitialRevealOverride,
    this.onCloseRequested,
  });

  final ExploreComic comic;
  final String heroTag;
  final bool isDesktopPanel;
  final bool? shouldAnimateInitialRevealOverride;
  final VoidCallback? onCloseRequested;

  @override
  State<ComicDetailPage> createState() => _ComicDetailPageState();
}

class _ComicDetailPageState extends State<ComicDetailPage>
    with TickerProviderStateMixin {
  static const _mediaChannel = MethodChannel('hazuki.comics/media');
  static final Set<String> _animatedComicDetailIds = <String>{};

  late Future<ComicDetailsData> _future;
  late final ValueNotifier<double> _appBarSolidProgressNotifier;
  late final ValueNotifier<bool> _collapsedTitleNotifier;
  late final TabController _tabController;
  late final bool _shouldAnimateInitialDetailReveal;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _actionButtonsKey = GlobalKey();
  final GlobalKey _favoriteRowKey = GlobalKey();
  final GlobalKey _headerTitleKey = GlobalKey();

  bool _favoriteBusy = false;
  bool? _favoriteOverride;
  bool? _cloudFavoriteOverride;
  bool _comicDynamicColorEnabled = false;
  bool _didBindComicDynamicColorSetting = false;
  bool? _observedComicDynamicColorEnabled;
  ColorScheme? _lightComicScheme;
  ColorScheme? _darkComicScheme;
  String _appBarComicTitle = '';
  String _appBarUpdateTime = '';
  Map<String, dynamic>? _lastReadProgress;
  int _lastTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeComicDetailPage();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncComicDynamicColorSettingFromScope();
  }

  @override
  void dispose() {
    _disposeComicDetailPage();
    super.dispose();
  }

  void _updateComicDetailState(VoidCallback update) {
    if (!mounted) {
      return;
    }
    setState(update);
  }

  @override
  Widget build(BuildContext context) {
    final theme = _buildDetailTheme(Theme.of(context));
    final topInset = MediaQuery.of(context).padding.top + kToolbarHeight;
    final surface = theme.colorScheme.surface;

    return AnimatedTheme(
      data: theme,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      child: Scaffold(
        backgroundColor: surface,
        extendBodyBehindAppBar: true,
        resizeToAvoidBottomInset: false,
        appBar: _ComicDetailScrollAwareAppBar(
          collapsedTitleListenable: _collapsedTitleNotifier,
          appBarComicTitle: _appBarComicTitle,
          appBarUpdateTime: _appBarUpdateTime,
          theme: theme,
          isDesktopPanel: widget.isDesktopPanel,
          onCloseRequested: widget.onCloseRequested,
        ),
        body: Stack(
          children: [
            _ComicDetailParallaxBackground(
              coverUrl: widget.comic.cover.trim(),
              scrollController: _scrollController,
            ),
            _ComicDetailTopSurfaceOverlay(
              progressListenable: _appBarSolidProgressNotifier,
              surface: surface,
              height: topInset,
            ),
            Padding(
              padding: EdgeInsets.only(top: topInset),
              child: _ComicDetailBody(
                tabController: _tabController,
                future: _future,
                scrollController: _scrollController,
                surface: surface,
                heroTag: widget.heroTag,
                comic: widget.comic,
                headerTitleKey: _headerTitleKey,
                favoriteRowKey: _favoriteRowKey,
                actionButtonsKey: _actionButtonsKey,
                favoriteBusy: _favoriteBusy,
                favoriteOverride: _favoriteOverride,
                lastReadProgress: _lastReadProgress,
                shouldAnimateInitialDetailReveal:
                    _shouldAnimateInitialDetailReveal,
                buildViewsText: _extractComicViewsText,
                buildMetaSection: _buildDetailMetaSection,
                onShowCoverPreview: (imageUrl) =>
                    unawaited(_showCoverPreview(imageUrl)),
                onFavoriteTap: _toggleFavorite,
                onShowChapters: _showChaptersPanel,
                onOpenReader: _openReader,
                onDetailsLoaded: _markComicDetailRevealHandled,
                onDetailsResolved: ({required title, required updateTime}) {
                  _updateAppBarMetadata(title: title, updateTime: updateTime);
                },
                isDesktopPanel: widget.isDesktopPanel,
                onCloseRequested: widget.onCloseRequested,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
