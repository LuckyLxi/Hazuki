import 'package:flutter/foundation.dart';
import 'package:hazuki/services/source/source_capabilities.dart';

const int _defaultCacheMaxBytes = 400 * 1024 * 1024;
const String _defaultAutoCleanMode = 'size_overflow';

class CacheSettingsController extends ChangeNotifier {
  CacheSettingsController({required SourceSettingsGateway sourceService})
    : _sourceService = sourceService;

  final SourceSettingsGateway _sourceService;

  bool _loading = true;
  int _maxBytes = _defaultCacheMaxBytes;
  int _usedBytes = 0;
  String _autoCleanMode = _defaultAutoCleanMode;
  bool _disposed = false;

  bool get loading => _loading;
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
    if (_disposed) return;
    _loading = true;
    _notify();
    try {
      await _sourceService.clearImageCache();
    } finally {
      await loadStatus();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
