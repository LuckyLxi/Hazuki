import 'package:flutter/foundation.dart';

import 'source_plugin_exception.dart';

/// Shared declarations for any host menu. Leaves select a value or run an action.
class SourceMenuEntry {
  const SourceMenuEntry({
    this.id,
    this.title,
    String? value,
    String? order,
    this.action,
    this.children = const [],
  }) : value = value ?? order;

  final String? id;
  final Object? title;
  final String? value;
  // Compatibility with the original favoriteMenu schema.
  String? get order => value;
  final String? action;
  final List<SourceMenuEntry> children;

  static List<SourceMenuEntry> parseList(Object? value) {
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

    List<SourceMenuEntry> parse(Object? raw, int depth) {
      if (raw is! List || depth > 4) invalid();
      final keys = <String>{};
      return List.unmodifiable(
        raw.map((item) {
          if (item is! Map || ++count > 100) invalid();
          final hasValue = item.containsKey('value');
          if (hasValue && item.containsKey('order')) invalid();
          final order = hasValue ? item['value'] : item['order'];
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
                !(hasValue ? order is String : identifier(order ?? action)) ||
                (action != null && !text(title))) {
              invalid();
            }
            key = order != null ? 'order:$order' : 'action:$action';
          }
          if (!keys.add(key)) invalid();
          return SourceMenuEntry(
            id: id as String?,
            title: title,
            value: order as String?,
            action: action as String?,
            children: children == null ? const [] : parse(children, depth + 1),
          );
        }),
      );
    }

    return value == null ? const [] : parse(value, 1);
  }

  /// Menu IDs are host-defined strings, without a fixed slot whitelist.
  static Map<String, List<SourceMenuEntry>> parseMenus(Object? value) {
    if (value == null) return const {};
    if (value is! Map ||
        value.keys.any(
          (key) => key is! String || key.trim().isEmpty || key != key.trim(),
        ) ||
        value.values.any((entries) => entries is! List)) {
      throw const SourcePluginException('plugin_invalid_manifest');
    }
    return Map.unmodifiable({
      for (final entry in value.entries)
        entry.key as String: parseList(entry.value),
    });
  }

  static List<SourceMenuEntry> forLocation(
    Map<String, dynamic> presentation,
    String menuId,
  ) {
    final menus = presentation['menus'];
    if (menus is Map && menus.containsKey(menuId)) {
      return parseList(menus[menuId]);
    }
    return menuId == 'favorites.cloud.sort'
        ? parseList(presentation['favoriteMenu'])
        : const [];
  }

  Map<String, Object?> toJson() => {
    if (id != null) 'id': id,
    if (title != null) 'title': title,
    if (value != null) 'value': value,
    if (action != null) 'action': action,
    if (children.isNotEmpty)
      'children': children.map((e) => e.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) =>
      other is SourceMenuEntry &&
      id == other.id &&
      value == other.value &&
      action == other.action &&
      (title is Map && other.title is Map
          ? mapEquals(title as Map, other.title as Map)
          : title == other.title) &&
      listEquals(children, other.children);

  @override
  int get hashCode => Object.hash(
    id,
    value,
    action,
    title is Map
        ? Object.hashAllUnordered(
            (title as Map).entries.map((e) => Object.hash(e.key, e.value)),
          )
        : title,
    Object.hashAll(children),
  );
}
