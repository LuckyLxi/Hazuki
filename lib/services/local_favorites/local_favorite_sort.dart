const localFavoriteSortOrders = ['savedNewest', 'savedOldest', 'updatedNewest'];

/// Old preferences stored plugin codes. Only migration needs those codes now.
String normalizeLocalFavoriteSort(
  String order, {
  Map<String, dynamic> presentation = const {},
}) {
  final normalized = order.trim();
  if (localFavoriteSortOrders.contains(normalized)) return normalized;
  final mappings = presentation['localFavoriteOrders'];
  final mapped = mappings is Map ? mappings[normalized] : null;
  if (localFavoriteSortOrders.contains(mapped)) return mapped as String;
  return switch (normalized) {
    'da' => 'savedOldest',
    'mp' || '-datetime_updated' => 'updatedNewest',
    _ => 'savedNewest',
  };
}
