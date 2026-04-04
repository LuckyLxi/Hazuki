part of '../comic_detail_page.dart';

extension _ComicDetailRuntimeExtension on _ComicDetailPageState {
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
    if (!mounted) {
      return;
    }
    _updateComicDetailState(() {
      _comicDynamicColorEnabled = enabled;
    });
    if (!enabled) {
      return;
    }
    unawaited(_scheduleDynamicColorExtraction());
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
      final cachedBytes = _dynamicColorImageCache[url];
      final bytes =
          cachedBytes ??
          await HazukiSourceService.instance.downloadImageBytes(
            url,
            keepInMemory: true,
          );
      if (!mounted) {
        return;
      }
      if (cachedBytes == null) {
        _dynamicColorImageCache[url] = bytes;
      }
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

      if (!mounted) {
        return;
      }
      _updateComicDetailState(() {
        _lightComicScheme = resolvedLight;
        _darkComicScheme = resolvedDark;
      });
    } catch (_) {}
  }
}
