import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hazuki/services/source/gateways/source_plugin_gateway.dart';
import 'package:hazuki/services/source/interaction/source_ui_scope.dart';
import 'package:hazuki/services/source/interaction/source_ui_service.dart';
import 'package:hazuki/services/source/plugins/source_menu.dart';
import 'package:hazuki/services/source/plugins/source_plugin_localization.dart';
import 'package:hazuki/shared/source_presentation.dart';

import 'hazuki_frosted_menu_core.dart';
import 'hazuki_prompt.dart';

export 'package:hazuki/services/source/plugins/source_menu.dart';

/// Connects any menu to presentation.menus[menuId]. IDs are chosen by callers.
class SourcePluginMenuBinding<T> {
  const SourcePluginMenuBinding({
    required this.menuId,
    this.sourceKey,
    this.gateway,
    this.entries,
    this.valueId,
    this.appendUnmentionedOptions = true,
  });

  final String menuId;

  /// Omitted uses the active source. Pass a source explicitly for saved content.
  final String? sourceKey;
  final SourcePluginGateway? gateway;

  /// Optional already-resolved declarations, e.g. from a controller snapshot.
  final List<SourceMenuEntry>? entries;
  final String Function(T)? valueId;
  final bool appendUnmentionedOptions;

  ResolvedSourcePluginMenu resolve(BuildContext context, {bool listen = true}) {
    final registry = listen
        ? SourcePresentationScope.maybeOf(context)
        : SourcePresentationScope.read(context);
    final key = sourceKey ?? registry?.activeSourceKey ?? '';
    final plugins =
        gateway ?? SourcePresentationScope.pluginsOf(context, listen: listen);
    final plugin = plugins?.pluginFor(key);
    final allowed =
        (plugins == null || plugin?.enabled == true) &&
        (registry == null || registry.isAllowedSourceKey(key));
    return ResolvedSourcePluginMenu(
      sourceKey: key,
      gateway: plugins,
      entries: allowed
          ? entries ??
                SourceMenuEntry.forLocation(
                  registry?.presentationFor(key) ??
                      plugin?.manifest.presentation ??
                      const {},
                  menuId,
                )
          : const [],
      translation: plugin?.manifest.translation ?? const {},
      canRunActions: allowed && plugin?.enabled == true,
      available: allowed,
    );
  }
}

class ResolvedSourcePluginMenu {
  const ResolvedSourcePluginMenu({
    required this.sourceKey,
    required this.gateway,
    required this.entries,
    required this.translation,
    required this.canRunActions,
    required this.available,
  });
  final String sourceKey;
  final SourcePluginGateway? gateway;
  final List<SourceMenuEntry> entries;
  final Map<String, dynamic> translation;
  final bool canRunActions;
  final bool available;
}

class _SourceMenuLayout<T> {
  _SourceMenuLayout({
    required List<HazukiFrostedMenuOption<T>> hostOptions,
    required ResolvedSourcePluginMenu menu,
    required SourcePluginMenuBinding<T> binding,
    required String language,
    T? selected,
  }) {
    void collect(List<HazukiFrostedMenuOption<T>> entries) {
      for (final entry in entries) {
        if (entry.children.isNotEmpty) {
          collect(entry.children);
        } else {
          final value = entry.value as T;
          values[binding.valueId?.call(value) ?? value.toString()] = entry;
        }
      }
    }

    collect(hostOptions);
    final selectedId = selected == null
        ? null
        : binding.valueId?.call(selected) ?? selected.toString();
    final used = <String>{};
    List<HazukiFrostedMenuOption<SourceMenuEntry>> build(
      List<SourceMenuEntry> entries,
      String path,
    ) {
      final result = <HazukiFrostedMenuOption<SourceMenuEntry>>[];
      for (final (index, entry) in entries.indexed) {
        final host = values[entry.value];
        final title = localizeSourcePluginText(
          entry.title,
          language,
          translation: menu.translation,
          fallback: host?.label ?? entry.id ?? entry.action ?? '',
        );
        final key = ValueKey(
          'source-plugin-menu-${binding.menuId}-$path-$index',
        );
        if (entry.children.isNotEmpty) {
          final children = build(entry.children, '$path-$index');
          if (children.isNotEmpty) {
            result.add(
              HazukiFrostedMenuOption.submenu(
                key: key,
                label: title,
                children: children,
              ),
            );
          }
        } else if (entry.value != null && host != null) {
          final choice = SourceMenuEntry(value: entry.value);
          used.add(entry.value!);
          if (entry.value == selectedId) selectedEntry ??= choice;
          result.add(
            HazukiFrostedMenuOption(key: key, value: choice, label: title),
          );
        } else if (entry.action != null && menu.canRunActions) {
          result.add(
            HazukiFrostedMenuOption(key: key, value: entry, label: title),
          );
        }
      }
      return result;
    }

    options.addAll(build(menu.entries, 'root'));
    for (final host in values.entries.where(
      (e) => binding.appendUnmentionedOptions && !used.contains(e.key),
    )) {
      final entry = SourceMenuEntry(value: host.key);
      if (host.key == selectedId) selectedEntry ??= entry;
      options.add(
        HazukiFrostedMenuOption(value: entry, label: host.value.label),
      );
    }
  }
  final values = <String, HazukiFrostedMenuOption<T>>{};
  final options = <HazukiFrostedMenuOption<SourceMenuEntry>>[];
  SourceMenuEntry? selectedEntry;
}

/// Shared by buttons, dropdowns and callers of showHazukiFrostedMenu.
Future<T?> showSourcePluginMenu<T>({
  required BuildContext context,
  required GlobalKey anchorKey,
  required List<HazukiFrostedMenuOption<T>> options,
  required SourcePluginMenuBinding<T> binding,
  T? selected,
  String? label,
  String keyPrefix = 'hazuki-frosted-menu',
  Listenable? dismissOn,
  ValueChanged<bool>? onActionBusyChanged,
  bool waitForDismissal = false,
}) async {
  final menu = binding.resolve(context, listen: false);
  if (menu.entries.isEmpty) {
    return showHazukiFrostedMenuCore(
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
  final layout = _SourceMenuLayout<T>(
    hostOptions: options,
    menu: menu,
    binding: binding,
    language: Localizations.localeOf(context).toLanguageTag(),
    selected: selected,
  );
  final owner = SourceUiOwner();
  var cancelled = false;
  void cancel() {
    cancelled = true;
    owner.cancel('ownerGone');
  }

  dismissOn?.addListener(cancel);
  try {
    final entry = await showHazukiFrostedMenuCore<SourceMenuEntry>(
      context: context,
      anchorKey: anchorKey,
      options: layout.options,
      selected: layout.selectedEntry,
      label: label,
      keyPrefix: keyPrefix,
      dismissOn: dismissOn,
      waitForDismissal: true,
    );
    if (cancelled || !context.mounted || entry == null) return null;
    final current = binding.resolve(context, listen: false);
    if (current.sourceKey != menu.sourceKey || !current.available) return null;
    if (entry.value != null) return layout.values[entry.value]?.value;
    if (!current.canRunActions ||
        current.gateway == null ||
        entry.action == null) {
      return null;
    }
    onActionBusyChanged?.call(true);
    try {
      final result = await owner.run(
        () => current.gateway!.runAction(menu.sourceKey, entry.action!),
      );
      if (!cancelled && context.mounted && result != null) {
        unawaited(
          showHazukiPrompt(
            context,
            localizeSourcePluginText(
              result,
              Localizations.localeOf(context).toLanguageTag(),
              translation: current.translation,
            ),
          ),
        );
      }
    } catch (error) {
      if (!cancelled && context.mounted && !isSourceUiCancellation(error)) {
        unawaited(showHazukiPrompt(context, error.toString(), isError: true));
      }
    } finally {
      onActionBusyChanged?.call(false);
    }
    return null;
  } finally {
    dismissOn?.removeListener(cancel);
    owner.dispose();
  }
}
