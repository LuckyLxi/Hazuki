import 'package:hazuki/shared/lru_cache.dart';

const int _animatedComicDetailIdsLimit = 200;
final LruCache<String, bool> _animatedComicDetailIds = LruCache<String, bool>(
  maxSize: _animatedComicDetailIdsLimit,
);

void markComicDetailIdAnimated(String id) {
  if (id.isEmpty) return;
  _animatedComicDetailIds.put(id, true);
}

bool wasComicDetailIdAnimated(String id) {
  if (id.isEmpty) return false;
  return _animatedComicDetailIds.contains(id);
}
