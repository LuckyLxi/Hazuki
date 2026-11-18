import 'package:flutter/foundation.dart';
import 'package:hazuki/services/source/source_capabilities.dart';

const int _defaultCacheMaxBytes = 400 * 1024 * 1024;
const String _defaultAutoCleanMode = 'size_overflow';

class CacheSettingsController extends ChangeNotifier {
  CacheSettingsController({required SourceSettingsGateway sourceService})
    : _sourceService = sourceService,
      _maxBytes = sourceService.imageCacheMaxBytes;

  final SourceSettingsGateway _sourceService;

  bool _loading = true;
  bool _initialized = false;
  bool _clearing = false;
  int _maxBytes;
  int _usedBytes = 0;
  String _autoCleanMode = _defaultAutoCleanMode;
  bool _disposed = false;

  bool get loading => _loading;

  /// 首次加载完成后为 true，之后的刷新不再回到加载占位态。
  bool get initialized => _initialized;
  bool get clearing => _clearing;
  int get maxBytes => _maxBytes;
  int get usedBytes => _usedBytes;
  String get autoCleanMode => _autoCleanMode;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> loadStatus() async {
    if (_disposed) return;
    _loading = true;
    _notify();
    try {
      final status = await _sourceService.getImageCacheStatus();
      if (_disposed) return;
      _maxBytes = (status['maxBytes'] as int?) ?? _defaultCacheMaxBytes;
      _usedBytes = (status['usedBytes'] as int?) ?? 0;
      _autoCleanMode =
          (status['autoCleanMode'] as String?) ?? _defaultAutoCleanMode;
    } catch (_) {
      // keep prior values
    } finally {
      if (!_disposed) {
        _loading = false;
        _initialized = true;
        _notify();
      }
    }
  }

  Future<int> setMaxBytesFromMb(int requestedMb) async {
    final normalizedMb = requestedMb < 400 ? 400 : requestedMb;
    await _sourceService.setImageCacheMaxBytes(normalizedMb * 1024 * 1024);
    await loadStatus();
    return normalizedMb;
  }

  Future<void> setAutoCleanMode(String mode) async {
    await _sourceService.setImageCacheAutoCleanMode(mode);
    await loadStatus();
  }

  Future<void> clearCache() async {
    if (_disposed || _clearing) return;
    // 清理期间保留现有数值，完成后由刷新驱动用量回落动画。
    _clearing = true;
    _notify();
    try {
      await _sourceService.clearImageCache();
    } finally {
      await loadStatus();
      _clearing = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
