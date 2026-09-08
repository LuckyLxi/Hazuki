import 'package:hazuki/services/source/source_capabilities.dart';

/// Source-specific compatibility rules for the favorites page.
class FavoriteSourcePolicy {
  const FavoriteSourcePolicy();

  bool refreshOnCloudFavoritesChanged(String sourceKey) =>
      isHazukiCopyMangaSourceKey(sourceKey);

  String normalizeSortOrder(
    String order, {
    required List<String> allowedOrders,
  }) {
    final normalized = order.trim();
    if (allowedOrders.contains(normalized)) {
      return normalized;
    }
    if (allowedOrders.contains('-datetime_updated') && normalized == 'mp') {
      return '-datetime_updated';
    }
    if (allowedOrders.contains('-datetime_modifier') && normalized == 'mr') {
      return '-datetime_modifier';
    }
    if (allowedOrders.contains('mp') && normalized == '-datetime_updated') {
      return 'mp';
    }
    if (allowedOrders.contains('mr')) {
      return 'mr';
    }
    return allowedOrders.firstOrNull ?? 'mr';
  }
}
