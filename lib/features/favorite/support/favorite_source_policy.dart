import 'package:hazuki/services/source/plugins/source_presentation_metadata.dart';

class FavoriteSourcePolicy {
  const FavoriteSourcePolicy({
    SourcePresentationReader presentationFor = emptySourcePresentation,
  }) : _presentationFor = presentationFor;

  final SourcePresentationReader _presentationFor;

  bool refreshOnCloudFavoritesChanged(String sourceKey) =>
      _presentationFor(sourceKey.trim())['refreshCloudFavorites'] == true;

  String normalizeSortOrder(
    String order, {
    required List<String> allowedOrders,
    required String sourceKey,
  }) {
    final normalized = order.trim();
    if (allowedOrders.contains(normalized)) return normalized;
    final presentation = _presentationFor(sourceKey);
    final aliases = presentation['favoriteOrderAliases'];
    final alias = aliases is Map ? aliases[normalized] : null;
    if (alias is String && allowedOrders.contains(alias)) return alias;
    final defaultOrder = presentation['favoriteDefaultOrder'];
    if (defaultOrder is String && allowedOrders.contains(defaultOrder)) {
      return defaultOrder;
    }
    return allowedOrders.firstOrNull ?? '';
  }
}
