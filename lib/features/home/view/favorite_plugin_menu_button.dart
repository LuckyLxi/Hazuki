import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/services/source/gateways/source_plugin_gateway.dart';
import 'package:hazuki/services/source/interaction/source_ui_scope.dart';
import 'package:hazuki/services/source/interaction/source_ui_service.dart';
import 'package:hazuki/services/source/plugins/source_favorite_menu.dart';
import 'package:hazuki/services/source/plugins/source_plugin_localization.dart';
import 'package:hazuki/shared/favorites/favorite_app_bar_actions_state.dart';
import 'package:hazuki/widgets/widgets.dart';

/// Uses the same sort values and action runner as the existing app entry points.
class FavoritePluginMenuButton extends StatefulWidget {
  const FavoritePluginMenuButton({
    super.key,
    required this.state,
    required this.gateway,
    required this.sortLabel,
    required this.onSortSelected,
  });

  final FavoriteAppBarActionsState state;
  final SourcePluginGateway? gateway;
  final String Function(String) sortLabel;
  final ValueChanged<String> onSortSelected;

  @override
  State<FavoritePluginMenuButton> createState() =>
      _FavoritePluginMenuButtonState();
}

class _FavoritePluginMenuButtonState extends State<FavoritePluginMenuButton> {
  final _sourceUi = SourceUiOwner();
  bool _busy = false;

  @override
  void dispose() {
    _sourceUi.dispose();
    super.dispose();
  }

  Future<void> _select(SourceFavoriteMenuEntry entry) async {
    if (_busy) return;
    if (entry.order case final String order) {
      widget.onSortSelected(order);
      return;
    }
    final gateway = widget.gateway;
    final sourceKey = widget.state.sourceKey;
    final plugin = gateway?.pluginFor(sourceKey);
    if (gateway == null || plugin?.enabled != true || entry.action == null) {
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await _sourceUi.run(
        () => gateway.runAction(sourceKey, entry.action!),
      );
      if (mounted && result != null) {
        unawaited(
          showHazukiPrompt(
            context,
            localizeSourcePluginText(
              result,
              Localizations.localeOf(context).toLanguageTag(),
              translation: plugin!.manifest.translation,
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted && !isSourceUiCancellation(error)) {
        unawaited(showHazukiPrompt(context, error.toString(), isError: true));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usedOrders = <String>{};
    SourceFavoriteMenuEntry? selected;
    final language = Localizations.localeOf(context).toLanguageTag();
    final translation =
        widget.gateway
            ?.pluginFor(widget.state.sourceKey)
            ?.manifest
            .translation ??
        const <String, dynamic>{};
    List<HazukiFrostedMenuOption<SourceFavoriteMenuEntry>> buildOptions(
      List<SourceFavoriteMenuEntry> entries,
      String path,
    ) {
      final result = <HazukiFrostedMenuOption<SourceFavoriteMenuEntry>>[];
      for (final (index, entry) in entries.indexed) {
        final key = ValueKey('favorite-plugin-menu-$path-$index');
        final title = localizeSourcePluginText(
          entry.title,
          language,
          translation: translation,
          fallback: entry.order == null
              ? entry.id ?? entry.action ?? ''
              : widget.sortLabel(entry.order!),
        );
        if (entry.children.isNotEmpty) {
          final children = buildOptions(entry.children, '$path-$index');
          if (children.isNotEmpty) {
            result.add(
              HazukiFrostedMenuOption.submenu(
                key: key,
                label: title,
                children: children,
              ),
            );
          }
          continue;
        }
        // A stale runtime declaration cannot introduce unsupported sort values.
        if (entry.order case final String order) {
          if (!widget.state.sortOrders.contains(order)) continue;
          usedOrders.add(order);
          if (order == widget.state.currentSortOrder) selected ??= entry;
        } else if (widget.gateway == null) {
          continue;
        }
        result.add(
          HazukiFrostedMenuOption(key: key, value: entry, label: title),
        );
      }
      return result;
    }

    final options = buildOptions(widget.state.menu, 'root');
    for (final order in widget.state.sortOrders.where(
      (e) => !usedOrders.contains(e),
    )) {
      final entry = SourceFavoriteMenuEntry(order: order);
      if (order == widget.state.currentSortOrder) selected ??= entry;
      options.add(
        HazukiFrostedMenuOption(value: entry, label: widget.sortLabel(order)),
      );
    }
    return HazukiFrostedMenuButton<SourceFavoriteMenuEntry>(
      tooltip: l10n(context).homeSortTooltip,
      selected: selected,
      options: options,
      enabled: !_busy,
      waitForDismissal: true,
      icon: const Icon(Icons.sort_rounded),
      onSelected: (entry) => unawaited(_select(entry)),
    );
  }
}
