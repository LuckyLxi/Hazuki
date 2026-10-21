import 'package:flutter/foundation.dart';

import 'source_plugin_exception.dart';

/// Optional cloud favorites menu. Leaves either select an order or run an action.
class SourceFavoriteMenuEntry {
  const SourceFavoriteMenuEntry({
    this.id,
    this.title,
    this.order,
    this.action,
    this.children = const [],
  });

  final String? id;
  final Object? title;
  final String? order;
  final String? action;
  final List<SourceFavoriteMenuEntry> children;

  static List<SourceFavoriteMenuEntry> parseList(Object? value) {
    var count = 0;
    Never invalid() =>
        throw const SourcePluginException('plugin_invalid_manifest');
    bool identifier(Object? value) =>
        value is String && value.trim().isNotEmpty && value == value.trim();
    bool text(Object? value) =>
        (value is String && value.trim().isNotEmpty) ||
        (value is Map &&
            value.isNotEmpty &&
            value.values.any((v) => v is String && v.trim().isNotEmpty) &&
            value.entries.every((e) => e.key is String && e.value is String));

    List<SourceFavoriteMenuEntry> parse(Object? raw, int depth) {
      if (raw is! List || depth > 4) invalid();
      final keys = <String>{};
      return List.unmodifiable(
        raw.map((item) {
          if (item is! Map || ++count > 100) invalid();
          final order = item['order'];
          final action = item['action'];
          final children = item['children'];
          final id = item['id'];
          final title = item['title'];
          if ([order, action, children].where((v) => v != null).length != 1 ||
              (title != null && !text(title))) {
            invalid();
          }
          final String key;
          if (children != null) {
            if (!identifier(id) ||
                !text(title) ||
                children is! List ||
                children.isEmpty) {
              invalid();
            }
            key = 'menu:$id';
          } else {
            if (id != null ||
                !identifier(order ?? action) ||
                (action != null && !text(title))) {
              invalid();
            }
            key = order != null ? 'order:$order' : 'action:$action';
          }
          if (!keys.add(key)) invalid();
          return SourceFavoriteMenuEntry(
            id: id as String?,
            title: title,
            order: order as String?,
            action: action as String?,
            children: children == null ? const [] : parse(children, depth + 1),
          );
        }),
      );
    }

    return value == null ? const [] : parse(value, 1);
  }

  Map<String, Object?> toJson() => {
    if (id != null) 'id': id,
    if (title != null) 'title': title,
    if (order != null) 'order': order,
    if (action != null) 'action': action,
    if (children.isNotEmpty)
      'children': children.map((e) => e.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) =>
      other is SourceFavoriteMenuEntry &&
      id == other.id &&
      order == other.order &&
      action == other.action &&
      (title is Map && other.title is Map
          ? mapEquals(title as Map, other.title as Map)
          : title == other.title) &&
      listEquals(children, other.children);

  @override
  int get hashCode => Object.hash(
    id,
    order,
    action,
    title is Map
        ? Object.hashAllUnordered(
            (title as Map).entries.map((e) => Object.hash(e.key, e.value)),
          )
        : title,
    Object.hashAll(children),
  );
}
