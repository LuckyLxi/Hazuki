import 'source_plugin_localization.dart';

/// Plugin-owned comment ordering codes and localized labels.
class SourceCommentSortOptions {
  const SourceCommentSortOptions({
    this.orders = const {},
    this.defaultOrder = '',
  });

  factory SourceCommentSortOptions.fromPresentation(
    Map<String, dynamic> presentation,
  ) {
    final raw = presentation['commentOrders'];
    final orders = <String, dynamic>{
      if (raw is Map)
        for (final entry in raw.entries)
          if (entry.key is String &&
              (entry.key as String).trim().isNotEmpty &&
              entry.key == (entry.key as String).trim())
            entry.key as String: entry.value,
    };
    return SourceCommentSortOptions(
      orders: Map.unmodifiable(orders),
      defaultOrder: normalizeSourceOrder(
        '',
        orders: orders.keys,
        defaultOrder: presentation['commentDefaultOrder'],
      ),
    );
  }

  final Map<String, dynamic> orders;
  final String defaultOrder;

  String normalize(String order) => normalizeSourceOrder(
    order,
    orders: orders.keys,
    defaultOrder: defaultOrder,
  );
}

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
