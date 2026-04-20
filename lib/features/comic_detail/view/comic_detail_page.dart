import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hazuki/app/app.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/pages/search/search.dart';
import 'package:hazuki/services/hazuki_source_service.dart';
import 'package:hazuki/services/local_favorites_service.dart';
import 'package:hazuki/services/manga_download_service.dart';
import 'package:hazuki/widgets/widgets.dart';

import 'comic_detail_app_bar.dart';
import 'comic_detail_background.dart';
import 'comic_detail_cover.dart';
import 'comic_detail_favorite_dialog.dart';
import 'comic_detail_meta.dart';
import 'comic_detail_panels.dart';
import 'comic_detail_scaffold.dart';
import 'package:hazuki/features/reader/view/reader_page.dart';

const MethodChannel _comicDetailMediaChannel = MethodChannel(
  'hazuki.comics/media',
);
final Set<String> _animatedComicDetailIds = <String>{};

const int _comicDynamicColorSchemeCacheLimit = 24;
final Map<String, _ComicDynamicColorCacheEntry> _comicDynamicColorSchemeCache =
    <String, _ComicDynamicColorCacheEntry>{};
final Map<String, Future<_ComicDynamicColorCacheEntry>>
_comicDynamicColorSchemeInFlight =
    <String, Future<_ComicDynamicColorCacheEntry>>{};

class _ComicDynamicColorCacheEntry {
  const _ComicDynamicColorCacheEntry({
    required this.lightScheme,
    required this.darkScheme,
  });

  final ColorScheme lightScheme;
  final ColorScheme darkScheme;
}

_ComicDynamicColorCacheEntry? _takeComicDynamicColorScheme(String url) {
  final normalizedUrl = url.trim();
  if (normalizedUrl.isEmpty) {
    return null;
  }
  final entry = _comicDynamicColorSchemeCache.remove(normalizedUrl);
  if (entry == null) {
    return null;
  }
  _comicDynamicColorSchemeCache[normalizedUrl] = entry;
  return entry;
}

void _putComicDynamicColorScheme(
  String url,
  _ComicDynamicColorCacheEntry entry,
) {
  final normalizedUrl = url.trim();
  if (normalizedUrl.isEmpty) {
    return;
  }
  _comicDynamicColorSchemeCache.remove(normalizedUrl);
  _comicDynamicColorSchemeCache[normalizedUrl] = entry;
  while (_comicDynamicColorSchemeCache.length >
      _comicDynamicColorSchemeCacheLimit) {
    _comicDynamicColorSchemeCache.remove(
      _comicDynamicColorSchemeCache.keys.first,
    );
  }
}

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
  State<ComicDetailPage> createState() => ComicDetailPageState();
}

class ComicDetailPageState extends State<ComicDetailPage>
    with TickerProviderStateMixin {
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
  bool _isAnimatingCommentsFullscreen = false;
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
        appBar: ComicDetailScrollAwareAppBar(
          collapsedTitleListenable: _collapsedTitleNotifier,
          appBarComicTitle: _appBarComicTitle,
          appBarUpdateTime: _appBarUpdateTime,
          theme: theme,
          isDesktopPanel: widget.isDesktopPanel,
          onCloseRequested: widget.onCloseRequested,
        ),
        body: Stack(
          children: [
            ComicDetailParallaxBackground(
              coverUrl: widget.comic.cover.trim(),
              scrollController: _scrollController,
            ),
            ComicDetailTopSurfaceOverlay(
              progressListenable: _appBarSolidProgressNotifier,
              surface: surface,
              height: topInset,
            ),
            Padding(
              padding: EdgeInsets.only(top: topInset),
              child: ComicDetailBody(
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
                buildViewsText: extractComicViewsText,
                buildMetaSection: _buildDetailMetaSection,
                onShowCoverPreview: (imageUrl) =>
                    unawaited(_showCoverPreview(imageUrl)),
                onFavoriteTap: _toggleFavorite,
                onShowChapters: _showChaptersPanel,
                onOpenReader: _openReader,
                onDetailsLoaded: _markComicDetailRevealHandled,
                onRequestCommentsTabFullscreen: _ensureCommentsTabFullscreen,
                onDetailsResolved: ({required title, required updateTime}) {
                  _updateAppBarMetadata(title: title, updateTime: updateTime);
                },
                isDesktopPanel: widget.isDesktopPanel,
                onCloseRequested: widget.onCloseRequested,
                buildComicDetailPage: (comic, heroTag) => ComicDetailPage(
                  comic: comic,
                  heroTag: heroTag,
                  isDesktopPanel: widget.isDesktopPanel,
                  onCloseRequested: widget.onCloseRequested,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _initializeComicDetailPage() {
    _shouldAnimateInitialDetailReveal =
        widget.shouldAnimateInitialRevealOverride ??
        !_animatedComicDetailIds.contains(widget.comic.id.trim());
    _appBarSolidProgressNotifier = ValueNotifier<double>(0);
    _collapsedTitleNotifier = ValueNotifier<bool>(false);
    _tabController = TabController(length: 3, vsync: this)
      ..addListener(_handleTabChanged);
    _appBarComicTitle = widget.comic.title;
    _future = HazukiSourceService.instance
        .loadComicDetails(widget.comic.id)
        .timeout(const Duration(seconds: 30));
    _scrollController.addListener(_handleScroll);
    unawaited(_warmupReaderImages());
    unawaited(_loadReadingProgress());
    unawaited(_loadFavoriteOverrideState());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _updateAppBarSolidProgress();
    });
    unawaited(_recordHistory());
  }

  void _disposeComicDetailPage() {
    _tabController
      ..removeListener(_handleTabChanged)
      ..dispose();
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _appBarSolidProgressNotifier.dispose();
    _collapsedTitleNotifier.dispose();
  }

  void _handleTabChanged() {
    final nextIndex = _tabController.index;
    if (_lastTabIndex == nextIndex) {
      return;
    }
    _lastTabIndex = nextIndex;
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _handleScroll() {
    _updateAppBarSolidProgress();
  }

  Future<void> _ensureCommentsTabFullscreen() async {
    if (!mounted ||
        _tabController.index != 1 ||
        !_scrollController.hasClients ||
        _isAnimatingCommentsFullscreen) {
      return;
    }

    final position = _scrollController.position;
    final targetOffset = position.maxScrollExtent.clamp(0.0, double.infinity);
    final currentOffset = position.pixels.clamp(0.0, targetOffset);
    if (targetOffset <= 0 || currentOffset >= targetOffset - 1) {
      return;
    }

    _isAnimatingCommentsFullscreen = true;
    try {
      await _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } finally {
      _isAnimatingCommentsFullscreen = false;
    }
  }

  bool _updateAppBarSolidProgress() {
    if (!_scrollController.hasClients) {
      return false;
    }

    final offset = _scrollController.offset.clamp(0.0, double.infinity);
    const fadeStart = 72.0;
    const fadeDistance = 132.0;
    const titleCollapseEnterOffset = 198.0;
    const titleCollapseExitOffset = 162.0;

    final nextProgress = ((offset - fadeStart) / fadeDistance).clamp(0.0, 1.0);
    final wasCollapsed = _collapsedTitleNotifier.value;
    final titleCollapsed = wasCollapsed
        ? offset >= titleCollapseExitOffset
        : offset >= titleCollapseEnterOffset;

    final progressChanged =
        (_appBarSolidProgressNotifier.value - nextProgress).abs() >= 0.02;
    final titleChanged = titleCollapsed != _collapsedTitleNotifier.value;

    if (!progressChanged && !titleChanged) {
      return false;
    }

    if (progressChanged) {
      _appBarSolidProgressNotifier.value = nextProgress;
    }
    if (titleChanged) {
      _collapsedTitleNotifier.value = titleCollapsed;
    }
    return true;
  }

  void _updateAppBarMetadata({
    required String title,
    required String updateTime,
  }) {
    if (_appBarComicTitle == title && _appBarUpdateTime == updateTime) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (_appBarComicTitle == title && _appBarUpdateTime == updateTime) {
        return;
      }
      _updateComicDetailState(() {
        _appBarComicTitle = title;
        _appBarUpdateTime = updateTime;
      });
    });
  }

  void _markComicDetailRevealHandled(ComicDetailsData details) {
    final primaryId = widget.comic.id.trim();
    final resolvedId = details.id.trim();
    if (primaryId.isNotEmpty) {
      _animatedComicDetailIds.add(primaryId);
    }
    if (resolvedId.isNotEmpty) {
      _animatedComicDetailIds.add(resolvedId);
    }
  }

  ThemeData _buildDetailTheme(ThemeData baseTheme) {
    var theme = baseTheme;
    if (!_comicDynamicColorEnabled) {
      return theme;
    }
    var scheme = theme.brightness == Brightness.light
        ? _lightComicScheme
        : _darkComicScheme;
    if (scheme == null) {
      return theme;
    }
    if (theme.brightness == Brightness.dark &&
        theme.scaffoldBackgroundColor == Colors.black) {
      scheme = scheme.copyWith(
        surface: Colors.black,
        surfaceContainer: Colors.black,
        surfaceContainerLow: Colors.black,
        surfaceContainerLowest: Colors.black,
        surfaceContainerHigh: Colors.black,
        surfaceContainerHighest: Colors.black,
      );
      return theme.copyWith(
        scaffoldBackgroundColor: Colors.black,
        canvasColor: Colors.black,
        cardColor: Colors.black,
        colorScheme: scheme,
        textSelectionTheme: TextSelectionThemeData(
          selectionColor: scheme.primary.withValues(alpha: 0.38),
          selectionHandleColor: scheme.primary,
          cursorColor: scheme.primary,
        ),
      );
    }
    return theme.copyWith(
      colorScheme: scheme,
      textSelectionTheme: TextSelectionThemeData(
        selectionColor: scheme.primary.withValues(alpha: 0.38),
        selectionHandleColor: scheme.primary,
        cursorColor: scheme.primary,
      ),
    );
  }

  void _syncComicDynamicColorSettingFromScope() {
    final controller = HazukiThemeControllerScope.maybeOf(context);
    if (controller == null) {
      if (_didBindComicDynamicColorSetting) {
        return;
      }
      _didBindComicDynamicColorSetting = true;
      unawaited(_loadDynamicColorSetting());
      return;
    }

    final enabled = controller.settings.comicDetailDynamicColor;
    final hasBound = _didBindComicDynamicColorSetting;
    _didBindComicDynamicColorSetting = true;
    if (hasBound && _observedComicDynamicColorEnabled == enabled) {
      return;
    }
    _observedComicDynamicColorEnabled = enabled;
    unawaited(_applyComicDynamicColorSetting(enabled, immediate: hasBound));
  }

  Future<void> _loadFavoriteOverrideState() async {
    try {
      final details = await _future;
      final localFavorite = await LocalFavoritesService.instance
          .isComicFavorited(
            details.id.trim().isNotEmpty ? details.id : widget.comic.id,
          );
      if (!mounted) {
        return;
      }
      _updateComicDetailState(() {
        _favoriteOverride = details.isFavorite || localFavorite;
        _cloudFavoriteOverride = details.isFavorite;
      });
    } catch (_) {}
  }

  Future<void> _loadReadingProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('reading_progress_${widget.comic.id}');
      if (jsonStr != null) {
        if (!mounted) {
          return;
        }
        _updateComicDetailState(() {
          _lastReadProgress = jsonDecode(jsonStr);
        });
      }
    } catch (_) {}
  }

  Future<void> _recordHistory() async {
    try {
      final details = await _future;
      if (!mounted) {
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      var history = <Map<String, dynamic>>[];
      final jsonStr = prefs.getString('hazuki_read_history');
      if (jsonStr != null) {
        try {
          final List<dynamic> jsonList = jsonDecode(jsonStr);
          history = jsonList.cast<Map<String, dynamic>>();
        } catch (_) {}
      }

      final comicId = details.id.trim().isNotEmpty
          ? details.id
          : widget.comic.id;
      final coverUrl = details.cover.trim().isNotEmpty
          ? details.cover
          : widget.comic.cover;

      history.removeWhere((e) => e['id'] == comicId);
      history.insert(0, {
        'id': comicId,
        'title': details.title.isNotEmpty ? details.title : widget.comic.title,
        'cover': coverUrl,
        'subTitle': details.subTitle.isNotEmpty
            ? details.subTitle
            : widget.comic.subTitle,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      if (history.length > 70) {
        history = history.sublist(0, 70);
      }

      await prefs.setString('hazuki_read_history', jsonEncode(history));
    } catch (_) {}
  }

  Future<void> _warmupReaderImages() async {
    if (hazukiNoImageModeNotifier.value) {
      return;
    }
    try {
      final details = await _future;
      if (details.chapters.isEmpty) {
        return;
      }
      final first = details.chapters.entries.first;
      final images = await HazukiSourceService.instance.loadChapterImages(
        comicId: details.id,
        epId: first.key,
      );
      await HazukiSourceService.instance.prefetchComicImages(
        comicId: details.id,
        epId: first.key,
        imageUrls: images,
        count: 3,
        memoryCount: 1,
      );
    } catch (_) {}
  }

  Future<void> _loadDynamicColorSetting() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled =
        prefs.getBool('appearance_comic_detail_dynamic_color') ?? false;
    await _applyComicDynamicColorSetting(enabled, immediate: false);
  }

  Future<void> _applyComicDynamicColorSetting(
    bool enabled, {
    required bool immediate,
  }) async {
    if (!mounted) {
      return;
    }
    if (!enabled) {
      _updateComicDetailState(() {
        _comicDynamicColorEnabled = false;
        _lightComicScheme = null;
        _darkComicScheme = null;
      });
      return;
    }

    if (!_comicDynamicColorEnabled) {
      _updateComicDetailState(() {
        _comicDynamicColorEnabled = true;
      });
    }

    if (_applyCachedDynamicColorScheme(widget.comic.cover)) {
      return;
    }

    if (!immediate) {
      unawaited(_scheduleDynamicColorExtraction());
      return;
    }

    if (hazukiNoImageModeNotifier.value) {
      return;
    }
    final coverUrl = await _resolveDynamicColorCoverUrl();
    if (!mounted || !_comicDynamicColorEnabled || coverUrl.isEmpty) {
      return;
    }
    if (_applyCachedDynamicColorScheme(coverUrl)) {
      return;
    }
    unawaited(_extractColorScheme(coverUrl));
  }

  Future<void> _scheduleDynamicColorExtraction() async {
    await Future.delayed(const Duration(milliseconds: 620));
    if (!mounted ||
        !_comicDynamicColorEnabled ||
        hazukiNoImageModeNotifier.value) {
      return;
    }
    final coverUrl = await _resolveDynamicColorCoverUrl();
    if (coverUrl.isEmpty || !mounted) {
      return;
    }
    if (_applyCachedDynamicColorScheme(coverUrl)) {
      return;
    }
    unawaited(_extractColorScheme(coverUrl));
  }

  Future<String> _resolveDynamicColorCoverUrl() async {
    final coverUrl = widget.comic.cover.trim();
    if (coverUrl.isNotEmpty) {
      return coverUrl;
    }
    try {
      final details = await _future;
      final dCoverUrl = details.cover.trim();
      if (dCoverUrl.isNotEmpty) {
        return dCoverUrl;
      }
    } catch (_) {}
    return widget.comic.cover.trim();
  }

  Future<Color> _buildNeutralComicSeed(Uint8List bytes) async {
    final averageLuminance = await _estimateCoverAverageLuminance(bytes);
    if (averageLuminance == null) {
      return const Color(0xff7a7a7a);
    }
    final tone = (92 + (averageLuminance * 72)).round().clamp(92, 164).toInt();
    return Color.fromARGB(255, tone, tone, tone);
  }

  Future<double?> _estimateCoverAverageLuminance(Uint8List bytes) async {
    try {
      final codec = await instantiateImageCodec(
        bytes,
        targetWidth: 36,
        targetHeight: 36,
      );
      final frame = await codec.getNextFrame();
      final rgbaData = await frame.image.toByteData(
        format: ImageByteFormat.rawRgba,
      );
      final rgbaBytes = rgbaData?.buffer.asUint8List();
      if (rgbaBytes == null) {
        return null;
      }

      double totalLuminance = 0;
      var sampleCount = 0;
      for (var index = 0; index <= rgbaBytes.length - 4; index += 16) {
        final alpha = rgbaBytes[index + 3];
        if (alpha < 24) {
          continue;
        }
        final red = rgbaBytes[index] / 255;
        final green = rgbaBytes[index + 1] / 255;
        final blue = rgbaBytes[index + 2] / 255;
        totalLuminance += 0.2126 * red + 0.7152 * green + 0.0722 * blue;
        sampleCount++;
      }
      if (sampleCount == 0) {
        return null;
      }
      return totalLuminance / sampleCount;
    } catch (_) {
      return null;
    }
  }

  Future<ColorScheme> _buildNeutralComicScheme({
    required Uint8List bytes,
    required Brightness brightness,
  }) async {
    final seed = await _buildNeutralComicSeed(bytes);
    return ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
  }

  Future<void> _extractColorScheme(String url) async {
    try {
      final normalizedUrl = url.trim();
      if (normalizedUrl.isEmpty) {
        return;
      }
      final cachedEntry = _takeComicDynamicColorScheme(normalizedUrl);
      if (cachedEntry != null) {
        _applyDynamicColorSchemeEntry(cachedEntry);
        return;
      }

      final inFlight = _comicDynamicColorSchemeInFlight[normalizedUrl];
      final Future<_ComicDynamicColorCacheEntry> future;
      final bool createdFuture;
      if (inFlight != null) {
        future = inFlight;
        createdFuture = false;
      } else {
        future = () async {
          final bytes = await HazukiSourceService.instance.downloadImageBytes(
            normalizedUrl,
            keepInMemory: true,
          );
          final imgProvider = MemoryImage(bytes);
          final light = await ColorScheme.fromImageProvider(
            provider: imgProvider,
            brightness: Brightness.light,
          );

          final fallbackLight = ColorScheme.fromSeed(
            seedColor: const Color(0xff4285F4),
            brightness: Brightness.light,
          );

          late final ColorScheme resolvedLight;
          late final ColorScheme resolvedDark;
          if (light.primary == fallbackLight.primary) {
            resolvedLight = await _buildNeutralComicScheme(
              bytes: bytes,
              brightness: Brightness.light,
            );
            resolvedDark = await _buildNeutralComicScheme(
              bytes: bytes,
              brightness: Brightness.dark,
            );
          } else {
            resolvedLight = light;
            resolvedDark = await ColorScheme.fromImageProvider(
              provider: imgProvider,
              brightness: Brightness.dark,
            );
          }

          return _ComicDynamicColorCacheEntry(
            lightScheme: resolvedLight,
            darkScheme: resolvedDark,
          );
        }();
        _comicDynamicColorSchemeInFlight[normalizedUrl] = future;
        createdFuture = true;
      }

      try {
        final entry = await future;
        _putComicDynamicColorScheme(normalizedUrl, entry);
        _applyDynamicColorSchemeEntry(entry);
      } finally {
        if (createdFuture) {
          _comicDynamicColorSchemeInFlight.remove(normalizedUrl);
        }
      }
    } catch (_) {}
  }

  bool _applyCachedDynamicColorScheme(String url) {
    final entry = _takeComicDynamicColorScheme(url);
    if (entry == null) {
      return false;
    }
    _applyDynamicColorSchemeEntry(entry);
    return true;
  }

  void _applyDynamicColorSchemeEntry(_ComicDynamicColorCacheEntry entry) {
    if (!mounted) {
      return;
    }
    _updateComicDetailState(() {
      _lightComicScheme = entry.lightScheme;
      _darkComicScheme = entry.darkScheme;
    });
  }

  Future<void> _saveImageToDownloads(String imageUrl) async {
    try {
      final bytes = await HazukiSourceService.instance.downloadImageBytes(
        imageUrl,
      );
      final uri = Uri.tryParse(imageUrl);
      final lastSegment = uri?.pathSegments.isNotEmpty == true
          ? uri!.pathSegments.last
          : '';
      final defaultName = 'hazuki_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final fileName = lastSegment.isEmpty
          ? defaultName
          : lastSegment.split('?').first;
      Directory directory;
      if (Platform.isWindows) {
        final exeDir = File(Platform.resolvedExecutable).parent.path;
        directory = Directory('$exeDir/Saved_Images');
      } else {
        directory = Directory('/storage/emulated/0/Pictures/Hazuki');
      }
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      if (Platform.isAndroid) {
        await _comicDetailMediaChannel.invokeMethod<bool>('scanFile', {
          'path': file.path,
        });
      }
      if (!mounted) {
        return;
      }
      unawaited(
        showHazukiPrompt(context, l10n(context).comicDetailSavedToPath),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      unawaited(
        showHazukiPrompt(
          context,
          l10n(context).comicDetailSaveFailed('$e'),
          isError: true,
        ),
      );
    }
  }

  Future<void> _showCoverActions(String imageUrl) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final themedData = _buildDetailTheme(Theme.of(context));
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.32),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Theme(
          data: themedData,
          child: AlertDialog(
            title: Text(l10n(context).comicDetailSaveImage),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n(context).commonCancel),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  unawaited(_saveImageToDownloads(imageUrl));
                },
                child: Text(l10n(context).commonSave),
              ),
            ],
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final fadeCurved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final scaleCurved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: fadeCurved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.88, end: 1.0).animate(scaleCurved),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _showCoverPreview(String imageUrl) async {
    final normalized = imageUrl.trim();
    if (normalized.isEmpty) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();

    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black45,
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (dialogContext, animation, secondaryAnimation) {
          return ComicCoverPreviewPage(
            imageUrl: normalized,
            heroTag: widget.heroTag,
            onLongPress: () {
              unawaited(HapticFeedback.selectionClick());
              unawaited(_showCoverActions(normalized));
            },
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(opacity: curved, child: child);
        },
      ),
    );
  }

  Future<void> _toggleFavorite(ComicDetailsData details) async {
    if (_favoriteBusy) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await _showFavoriteFoldersPanel(details);
  }

  Future<void> _showFavoriteFoldersPanel(ComicDetailsData details) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final service = HazukiSourceService.instance;
    final singleFolderOnly = service.favoriteSingleFolderForSingleComic;

    final changed = await showGeneralDialog<Map<String, Set<String>>>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.46),
      transitionDuration: const Duration(milliseconds: 420),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final themedData = _buildDetailTheme(Theme.of(context));
        return Theme(
          data: themedData,
          child: FavoriteFoldersMorphDialog(
            details: details,
            singleFolderOnly: singleFolderOnly,
            cloudFavoriteOverride: _cloudFavoriteOverride,
            initialIsFavorite: details.isFavorite,
          ),
        );
      },
      transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
        final scale = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        );
        final opacity = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final slide =
            Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              ),
            );
        return FadeTransition(
          opacity: opacity,
          child: SlideTransition(
            position: slide,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.9, end: 1).animate(scale),
              child: child,
            ),
          ),
        );
      },
    );

    if (changed == null || !mounted) {
      return;
    }

    final selectedResult = Set<String>.from(changed['selected'] ?? <String>{});
    final initialFavoritedResult = Set<String>.from(
      changed['initial'] ?? <String>{},
    );

    final addTargets = selectedResult.difference(initialFavoritedResult);
    final removeTargets = initialFavoritedResult.difference(selectedResult);

    if (addTargets.isEmpty && removeTargets.isEmpty) {
      return;
    }

    _updateComicDetailState(() {
      _favoriteBusy = true;
    });

    try {
      await _applyFavoriteSelectionChanges(
        details: details,
        selectedResult: selectedResult,
        initialFavoritedResult: initialFavoritedResult,
        singleFolderOnly: singleFolderOnly,
      );

      if (!mounted) {
        return;
      }
      unawaited(
        showHazukiPrompt(
          context,
          l10n(context).comicDetailFavoriteSettingsUpdated,
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      unawaited(
        showHazukiPrompt(
          context,
          l10n(context).comicDetailFavoriteSettingsUpdateFailed('$e'),
          isError: true,
        ),
      );
    } finally {
      if (mounted) {
        _updateComicDetailState(() {
          _favoriteBusy = false;
        });
      }
    }
  }

  Future<void> _applyFavoriteSelectionChanges({
    required ComicDetailsData details,
    required Set<String> selectedResult,
    required Set<String> initialFavoritedResult,
    required bool singleFolderOnly,
  }) async {
    final service = HazukiSourceService.instance;
    final localService = LocalFavoritesService.instance;
    final selectedHandles = _favoriteHandlesFromStorageKeys(selectedResult);
    final initialHandles = _favoriteHandlesFromStorageKeys(
      initialFavoritedResult,
    );

    final selectedCloudIds = _folderIdsForSource(
      selectedHandles,
      FavoriteFolderSource.cloud,
    );
    final initialCloudIds = _folderIdsForSource(
      initialHandles,
      FavoriteFolderSource.cloud,
    );
    final selectedLocalIds = _folderIdsForSource(
      selectedHandles,
      FavoriteFolderSource.local,
    );
    final initialLocalIds = _folderIdsForSource(
      initialHandles,
      FavoriteFolderSource.local,
    );

    if (singleFolderOnly && service.isLogged && service.supportFavoriteToggle) {
      if (selectedCloudIds.isEmpty && initialCloudIds.isNotEmpty) {
        await service.toggleFavorite(
          comicId: details.id,
          isAdding: false,
          folderId: initialCloudIds.first,
        );
      } else if (selectedCloudIds.isNotEmpty &&
          !_setContentsEqual(selectedCloudIds, initialCloudIds)) {
        await service.toggleFavorite(
          comicId: details.id,
          isAdding: true,
          folderId: selectedCloudIds.first,
        );
      }
    } else if (service.isLogged && service.supportFavoriteToggle) {
      final addCloudIds = selectedCloudIds.difference(initialCloudIds);
      final removeCloudIds = initialCloudIds.difference(selectedCloudIds);
      for (final folderId in addCloudIds) {
        await service.toggleFavorite(
          comicId: details.id,
          isAdding: true,
          folderId: folderId,
        );
      }
      for (final folderId in removeCloudIds) {
        await service.toggleFavorite(
          comicId: details.id,
          isAdding: false,
          folderId: folderId,
        );
      }
    }

    final addLocalIds = selectedLocalIds.difference(initialLocalIds);
    final removeLocalIds = initialLocalIds.difference(selectedLocalIds);
    for (final folderId in addLocalIds) {
      await localService.toggleFavorite(
        details: details,
        isAdding: true,
        folderId: folderId,
      );
    }
    for (final folderId in removeLocalIds) {
      await localService.toggleFavorite(
        details: details,
        isAdding: false,
        folderId: folderId,
      );
    }

    _favoriteOverride = selectedResult.isNotEmpty;
    _cloudFavoriteOverride = selectedCloudIds.isNotEmpty;
  }

  Set<FavoriteFolderHandle> _favoriteHandlesFromStorageKeys(Set<String> keys) {
    final handles = <FavoriteFolderHandle>{};
    for (final key in keys) {
      final handle = favoriteFolderHandleFromStorageKey(key);
      if (handle != null) {
        handles.add(handle);
      }
    }
    return handles;
  }

  Set<String> _folderIdsForSource(
    Set<FavoriteFolderHandle> handles,
    FavoriteFolderSource source,
  ) {
    return handles
        .where((handle) => handle.source == source)
        .map((handle) => handle.id)
        .toSet();
  }

  bool _setContentsEqual(Set<String> left, Set<String> right) {
    return left.length == right.length && left.containsAll(right);
  }

  void _showChaptersPanel(ComicDetailsData details) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (details.chapters.isEmpty) {
      unawaited(
        showHazukiPrompt(
          context,
          l10n(context).comicDetailNoChapterInfo,
          isError: true,
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      useSafeArea: false,
      sheetAnimationStyle: AnimationStyle(
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
        reverseDuration: const Duration(milliseconds: 220),
        reverseCurve: Curves.easeInCubic,
      ),
      builder: (routeContext) {
        final themedData = _buildDetailTheme(Theme.of(routeContext));
        return Theme(
          data: themedData,
          child: ChaptersPanelSheet(
            details: details,
            onDownloadConfirm: (selectedEpIds) {
              Navigator.of(routeContext).pop();
              unawaited(
                _enqueueChapterDownloads(details, selectedEpIds: selectedEpIds),
              );
            },
            onChapterTap: (epId, chapterTitle, index) {
              Navigator.of(routeContext).pop();
              unawaited(
                _openReader(
                  details,
                  epId: epId,
                  chapterTitle: chapterTitle,
                  chapterIndex: index,
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _enqueueChapterDownloads(
    ComicDetailsData details, {
    required Set<String> selectedEpIds,
  }) async {
    if (selectedEpIds.isEmpty) {
      return;
    }
    final targets = <MangaChapterDownloadTarget>[];
    for (var i = 0; i < details.chapters.length; i++) {
      final entry = details.chapters.entries.elementAt(i);
      if (selectedEpIds.contains(entry.key)) {
        targets.add(
          MangaChapterDownloadTarget(
            epId: entry.key,
            title: resolveHazukiChapterTitle(context, entry.value),
            index: i,
          ),
        );
      }
    }
    if (targets.isEmpty) {
      return;
    }
    await MangaDownloadService.instance.enqueueDownload(
      details: details,
      coverUrl: details.cover.trim().isNotEmpty
          ? details.cover
          : widget.comic.cover,
      description: details.description,
      chapters: targets,
    );
    if (!mounted) {
      return;
    }
    unawaited(
      showHazukiPrompt(
        context,
        l10n(context).downloadsQueued('${targets.length}'),
      ),
    );
  }

  Future<void> _openReader(
    ComicDetailsData details, {
    String? epId,
    String? chapterTitle,
    int? chapterIndex,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final chapters = details.chapters;
    if (chapters.isEmpty) {
      if (!mounted) {
        return;
      }
      unawaited(
        showHazukiPrompt(
          context,
          l10n(context).comicDetailNoChapters,
          isError: true,
        ),
      );
      return;
    }

    MapEntry<String, String>? initialEntry;
    int finalIndex = 0;

    final hasMemory =
        _lastReadProgress != null &&
        chapters.containsKey(_lastReadProgress!['epId']) &&
        chapters.length > 1;

    if (epId != null && chapters.containsKey(epId)) {
      initialEntry = MapEntry(epId, chapters[epId]!);
      finalIndex = chapterIndex ?? chapters.keys.toList().indexOf(epId);
    } else if (hasMemory) {
      final memEpId = _lastReadProgress!['epId'] as String;
      initialEntry = MapEntry(memEpId, chapters[memEpId]!);
      finalIndex = _lastReadProgress!['index'] as int;
    } else {
      initialEntry = chapters.entries.first;
      finalIndex = 0;
    }

    final initialChapterTitle = resolveHazukiChapterTitle(
      context,
      (chapterTitle != null && chapterTitle.isNotEmpty)
          ? chapterTitle
          : initialEntry.value,
    );

    await Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => ReaderPage(
              title: details.title,
              chapterTitle: initialChapterTitle,
              comicId: details.id,
              epId: initialEntry!.key,
              chapterIndex: finalIndex,
              images: const [],
              comicTheme: _buildDetailTheme(Theme.of(context)),
            ),
          ),
        )
        .then((_) {
          FocusManager.instance.primaryFocus?.unfocus();
          if (mounted) {
            unawaited(_loadReadingProgress());
          }
        });
  }

  Widget _buildDetailMetaSection(ComicDetailsData details) {
    final strings = l10n(context);
    final authorLabel = strings.comicDetailAuthor;
    final tagLabel = strings.comicDetailTags;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ComicDetailIdRow(
          id: details.id,
          onCopy: () async {
            final id = details.id.trim();
            if (id.isEmpty) {
              return;
            }
            await Clipboard.setData(ClipboardData(text: id));
            if (!mounted) {
              return;
            }
            unawaited(showHazukiPrompt(context, strings.comicDetailCopiedId));
          },
        ),
        ComicDetailMetaRow(
          label: authorLabel,
          values: normalizeComicMetaValues(
            details.tags.keys
                .where(isComicAuthorKey)
                .expand((k) => details.tags[k] ?? const <String>[])
                .toList(),
            label: authorLabel,
          ),
          onValuePressed: (value) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SearchPage(
                  initialKeyword: value,
                  comicDetailPageBuilder: (comic, heroTag) => ComicDetailPage(
                    comic: comic,
                    heroTag: heroTag,
                    isDesktopPanel: widget.isDesktopPanel,
                    onCloseRequested: widget.onCloseRequested,
                  ),
                ),
              ),
            );
          },
          onValueLongPress: (value) async {
            unawaited(HapticFeedback.heavyImpact());
            await Clipboard.setData(ClipboardData(text: value));
            if (!mounted) {
              return;
            }
            unawaited(
              showHazukiPrompt(context, strings.comicDetailCopiedPrefix(value)),
            );
          },
        ),
        ComicDetailMetaRow(
          label: tagLabel,
          values: normalizeComicMetaValues(
            details.tags.entries
                .where(
                  (e) =>
                      !isComicAuthorKey(e.key) &&
                      e.key != details.tags.keys.lastOrNull,
                )
                .expand((e) => e.value)
                .toList(),
            label: tagLabel,
          ),
          onValuePressed: (value) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SearchPage(
                  initialKeyword: value,
                  comicDetailPageBuilder: (comic, heroTag) => ComicDetailPage(
                    comic: comic,
                    heroTag: heroTag,
                    isDesktopPanel: widget.isDesktopPanel,
                    onCloseRequested: widget.onCloseRequested,
                  ),
                ),
              ),
            );
          },
          onValueLongPress: (value) async {
            unawaited(HapticFeedback.heavyImpact());
            await Clipboard.setData(ClipboardData(text: value));
            if (!mounted) {
              return;
            }
            unawaited(
              showHazukiPrompt(context, strings.comicDetailCopiedPrefix(value)),
            );
          },
        ),
      ],
    );
  }
}
