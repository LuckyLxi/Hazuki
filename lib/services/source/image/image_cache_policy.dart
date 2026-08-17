import 'package:shared_preferences/shared_preferences.dart';

import '../common/source_prefs_keys.dart';

typedef ImageCacheOverflowTrimmer =
    Future<bool> Function({
      required int limitBytes,
      required double targetRatio,
    });

/// Owns image-cache preferences and automatic maintenance decisions.
class ImageCachePolicy {
  ImageCachePolicy({
    required SharedPreferences? Function() getPreferences,
    required Future<void> Function(Duration keepDuration) cleanByAge,
    required ImageCacheOverflowTrimmer trimToOverflow,
    DateTime Function()? now,
  }) : _getPreferences = getPreferences,
       _cleanByAge = cleanByAge,
       _trimToOverflow = trimToOverflow,
       _now = now ?? DateTime.now;

  final SharedPreferences? Function() _getPreferences;
  final Future<void> Function(Duration keepDuration) _cleanByAge;
  final ImageCacheOverflowTrimmer _trimToOverflow;
  final DateTime Function() _now;
  Future<void>? _enforceInFlight;

  int get maxBytes {
    final value =
        _getPreferences()?.getInt(SourcePrefsKeys.cacheMaxBytes) ??
        SourcePrefsKeys.defaultCacheMaxBytes;
    return value < SourcePrefsKeys.defaultCacheMaxBytes
        ? SourcePrefsKeys.defaultCacheMaxBytes
        : value;
  }

  Future<void> setMaxBytes(int value) async {
    final preferences = _getPreferences();
    if (preferences == null) return;
    final normalized = value < SourcePrefsKeys.defaultCacheMaxBytes
        ? SourcePrefsKeys.defaultCacheMaxBytes
        : value;
    await preferences.setInt(SourcePrefsKeys.cacheMaxBytes, normalized);
    await enforce();
  }

  String get autoCleanMode {
    final mode = _getPreferences()?.getString(
      SourcePrefsKeys.cacheAutoCleanMode,
    );
    return mode == 'seven_days' ? mode! : SourcePrefsKeys.defaultAutoCleanMode;
  }

  Future<void> setAutoCleanMode(String mode) async {
    final preferences = _getPreferences();
    if (preferences == null) return;
    final normalized = mode == 'seven_days' ? 'seven_days' : 'size_overflow';
    await preferences.setString(SourcePrefsKeys.cacheAutoCleanMode, normalized);
    await enforce(force: true);
  }

  Future<void> enforce({bool force = false}) {
    if (!force) {
      final inFlight = _enforceInFlight;
      if (inFlight != null) return inFlight;
    }
    final future = _enforceInternal(force: force);
    _enforceInFlight = future;
    return future.whenComplete(() {
      if (identical(_enforceInFlight, future)) _enforceInFlight = null;
    });
  }

  Future<void> _enforceInternal({required bool force}) async {
    final preferences = _getPreferences();
    if (preferences == null) return;

    final currentTime = _now();
    final mode = autoCleanMode;
    if (mode == 'seven_days') {
      final lastAtMs =
          preferences.getInt(SourcePrefsKeys.cacheLastAutoCleanAt) ?? 0;
      final shouldCleanByAge =
          force ||
          lastAtMs <= 0 ||
          currentTime.difference(
                DateTime.fromMillisecondsSinceEpoch(lastAtMs),
              ) >=
              const Duration(days: 7);
      if (shouldCleanByAge) {
        await _cleanByAge(const Duration(days: 1));
        await preferences.setInt(
          SourcePrefsKeys.cacheLastAutoCleanAt,
          currentTime.millisecondsSinceEpoch,
        );
      }
    }

    final trimmedByOverflow = await _trimToOverflow(
      limitBytes: maxBytes,
      targetRatio: SourcePrefsKeys.cacheOverflowTrimTargetRatio,
    );
    if (mode != 'seven_days' && trimmedByOverflow) {
      await preferences.setInt(
        SourcePrefsKeys.cacheLastAutoCleanAt,
        currentTime.millisecondsSinceEpoch,
      );
    }
  }
}
