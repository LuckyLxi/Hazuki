import 'package:flutter/material.dart';

import 'hazuki_frosted_menu_core.dart';
import 'source_plugin_menu.dart';

export 'hazuki_frosted_menu_core.dart' show HazukiFrostedMenuOption;
export 'source_plugin_menu.dart' show SourcePluginMenuBinding;

Future<T?> showHazukiFrostedMenu<T>({
  required BuildContext context,
  required GlobalKey anchorKey,
  required List<HazukiFrostedMenuOption<T>> options,
  T? selected,
  String? label,
  String keyPrefix = 'hazuki-frosted-menu',
  Listenable? dismissOn,
  bool waitForDismissal = false,
  SourcePluginMenuBinding<T>? pluginMenu,
}) async {
  if (pluginMenu != null) {
    return showSourcePluginMenu<T>(
      context: context,
      anchorKey: anchorKey,
      options: options,
      binding: pluginMenu,
      selected: selected,
      label: label,
      keyPrefix: keyPrefix,
      dismissOn: dismissOn,
      waitForDismissal: waitForDismissal,
    );
  }
  return showHazukiFrostedMenuCore<T>(
    context: context,
    anchorKey: anchorKey,
    options: options,
    selected: selected,
    label: label,
    keyPrefix: keyPrefix,
    dismissOn: dismissOn,
    waitForDismissal: waitForDismissal,
  );
}
