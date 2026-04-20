import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hazuki/app/app.dart';
import 'package:hazuki/services/hazuki_source_service.dart';

import 'comic_detail_controller_support.dart';

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

class ComicDetailThemeController {
  ComicDetailThemeController({
    required String comicCoverUrl,
    required ComicDetailContextGetter contextGetter,
    required ComicDetailIsMounted isMounted,
    required ComicDetailStateUpdate updateState,
    required ComicDetailDetailsFutureGetter detailsFutureGetter,
  }) : _comicCoverUrl = comicCoverUrl,
       _contextGetter = contextGetter,
       _isMounted = isMounted,
       _updateState = updateState,
       _detailsFutureGetter = detailsFutureGetter;

  final String _comicCoverUrl;
  final ComicDetailContextGetter _contextGetter;
  final ComicDetailIsMounted _isMounted;
  final ComicDetailStateUpdate _updateState;
  final ComicDetailDetailsFutureGetter _detailsFutureGetter;

  bool _comicDynamicColorEnabled = false;
  bool _didBindComicDynamicColorSetting = false;
  bool? _observedComicDynamicColorEnabled;
  ColorScheme? _lightComicScheme;
  ColorScheme? _darkComicScheme;

  ThemeData buildDetailTheme(ThemeData baseTheme) {
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

  void syncComicDynamicColorSettingFromScope() {
    final controller = HazukiThemeControllerScope.maybeOf(_contextGetter());
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
    if (!_isMounted()) {
      return;
    }
    if (!enabled) {
      _updateState(() {
        _comicDynamicColorEnabled = false;
        _lightComicScheme = null;
        _darkComicScheme = null;
      });
      return;
    }

    if (!_comicDynamicColorEnabled) {
      _updateState(() {
        _comicDynamicColorEnabled = true;
      });
    }

    if (_applyCachedDynamicColorScheme(_comicCoverUrl)) {
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
    if (!_isMounted() || !_comicDynamicColorEnabled || coverUrl.isEmpty) {
      return;
    }
    if (_applyCachedDynamicColorScheme(coverUrl)) {
      return;
    }
    unawaited(_extractColorScheme(coverUrl));
  }

  Future<void> _scheduleDynamicColorExtraction() async {
    await Future.delayed(const Duration(milliseconds: 620));
    if (!_isMounted() ||
        !_comicDynamicColorEnabled ||
        hazukiNoImageModeNotifier.value) {
      return;
    }
    final coverUrl = await _resolveDynamicColorCoverUrl();
    if (coverUrl.isEmpty || !_isMounted()) {
      return;
    }
    if (_applyCachedDynamicColorScheme(coverUrl)) {
      return;
    }
    unawaited(_extractColorScheme(coverUrl));
  }

  Future<String> _resolveDynamicColorCoverUrl() async {
    final coverUrl = _comicCoverUrl.trim();
    if (coverUrl.isNotEmpty) {
      return coverUrl;
    }
    try {
      final details = await _detailsFutureGetter();
      final dCoverUrl = details.cover.trim();
      if (dCoverUrl.isNotEmpty) {
        return dCoverUrl;
      }
    } catch (_) {}
    return _comicCoverUrl.trim();
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
    if (!_isMounted()) {
      return;
    }
    _updateState(() {
      _lightComicScheme = entry.lightScheme;
      _darkComicScheme = entry.darkScheme;
    });
  }
}
