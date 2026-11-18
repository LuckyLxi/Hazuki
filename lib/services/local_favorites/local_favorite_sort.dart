const localFavoriteSortOrders = ['savedNewest', 'savedOldest', 'readNewest'];

/// 已下线的策略：旧偏好或已发布插件的映射仍可能写入这些值。
const _retiredLocalFavoriteSortOrders = {'updatedNewest': 'readNewest'};

/// Old preferences stored plugin codes. Only migration needs those codes now.
String normalizeLocalFavoriteSort(
  String order, {
  Map<String, dynamic> presentation = const {},
}) {
  final normalized = order.trim();
  String? resolve(Object? value) {
    if (localFavoriteSortOrders.contains(value)) return value as String;
    return _retiredLocalFavoriteSortOrders[value];
  }

  final direct = resolve(normalized);
  if (direct != null) return direct;
  final mappings = presentation['localFavoriteOrders'];
  final mapped = resolve(mappings is Map ? mappings[normalized] : null);
  if (mapped != null) return mapped;
  return switch (normalized) {
    'da' => 'savedOldest',
    'mp' || '-datetime_updated' || '-datetime_browse' => 'readNewest',
    _ => 'savedNewest',
  };
}
