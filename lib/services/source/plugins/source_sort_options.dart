import 'source_plugin_localization.dart';

/// Keeps page selections and requests on the same plugin-declared ordering.
String normalizeSourceOrder(
  String order, {
  required Iterable<String> orders,
  Object? defaultOrder,
}) {
  final normalized = order.trim();
  if (orders.contains(normalized)) return normalized;
  final fallback = defaultOrder?.toString().trim() ?? '';
  return orders.contains(fallback) ? fallback : orders.firstOrNull ?? '';
}

String normalizeSourceSearchOrder(
  String order,
  Map<String, dynamic> presentation,
) {
  final options = presentation['searchOrders'];
  return normalizeSourceOrder(
    order,
    orders: options is Map
        ? options.keys.map((key) => key.toString())
        : const [],
    defaultOrder: presentation['searchDefaultOrder'],
  );
}

String sourceOrderLabel(Object? label, String language, String fallback) {
  return localizeSourcePluginText(label, language, fallback: fallback);
}
