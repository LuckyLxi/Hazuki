import 'dart:typed_data';
import '../../models/hazuki_models.dart';

const int _hazukiWidgetImageMemoryLimit = 300;
final Map<String, Uint8List> _hazukiWidgetImageMemory = <String, Uint8List>{};

String hazukiWidgetImageMemoryKey(String url, {String sourceKey = ''}) {
  return SourceScopedComicId(sourceKey: sourceKey, comicId: url).imageCacheKey;
}

Uint8List? peekHazukiWidgetImageMemory(String url, {String sourceKey = ''}) {
  final key = hazukiWidgetImageMemoryKey(url, sourceKey: sourceKey);
  return _hazukiWidgetImageMemory[key] ??
      (sourceKey.trim().isNotEmpty
          ? _hazukiWidgetImageMemory[url.trim()]
          : null);
}

Uint8List? takeHazukiWidgetImageMemory(String url, {String sourceKey = ''}) {
  final key = hazukiWidgetImageMemoryKey(url, sourceKey: sourceKey);
  final bytes =
      _hazukiWidgetImageMemory[key] ??
      (sourceKey.trim().isNotEmpty
          ? _hazukiWidgetImageMemory[url.trim()]
          : null);
  if (bytes == null) {
    return null;
  }
  _hazukiWidgetImageMemory.remove(key);
  _hazukiWidgetImageMemory[key] = bytes;
  return bytes;
}

void putHazukiWidgetImageMemory(
  String url,
  Uint8List bytes, {
  String sourceKey = '',
}) {
  final key = hazukiWidgetImageMemoryKey(url, sourceKey: sourceKey);
  _hazukiWidgetImageMemory.remove(key);
  _hazukiWidgetImageMemory[key] = bytes;
  while (_hazukiWidgetImageMemory.length > _hazukiWidgetImageMemoryLimit) {
    _hazukiWidgetImageMemory.remove(_hazukiWidgetImageMemory.keys.first);
  }
}

void clearHazukiWidgetImageMemoryForTesting() {
  _hazukiWidgetImageMemory.clear();
}
