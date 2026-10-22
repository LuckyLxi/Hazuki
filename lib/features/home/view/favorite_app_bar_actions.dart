import 'package:flutter/material.dart';

import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/shared/favorites/favorite_app_bar_actions_state.dart';
import 'package:hazuki/widgets/widgets.dart';
import 'package:hazuki/services/source/plugins/source_sort_options.dart';
import 'package:hazuki/services/source/gateways/source_plugin_gateway.dart';

class FavoriteAppBarActions extends StatelessWidget {
  const FavoriteAppBarActions({
    super.key,
    required this.state,
    required this.onSortSelected,
    required this.onCreateFolderPressed,
    required this.onModeTogglePressed,
    this.sourcePlugins,
  });

  final FavoriteAppBarActionsState state;
  final SourcePluginGateway? sourcePlugins;
  final ValueChanged<String> onSortSelected;
  final VoidCallback onCreateFolderPressed;
  final VoidCallback onModeTogglePressed;

  String _sortLabel(BuildContext context, String order) {
    if (state.currentMode == FavoritePageMode.cloud &&
        state.sortLabels.containsKey(order)) {
      return sourceOrderLabel(
        state.sortLabels[order],
        Localizations.localeOf(context).languageCode,
        order,
      );
    }
    return switch (order) {
      'savedNewest' => l10n(context).favoriteSortNewToOld,
      'savedOldest' => l10n(context).favoriteSortOldToNew,
      'readNewest' => l10n(context).homeFavoriteSortByReadTime,
      // Compatibility for plugins published before favoriteOrderLabels.
      'dd' => l10n(context).favoriteSortNewToOld,
      'da' => l10n(context).favoriteSortOldToNew,
      'mp' || '-datetime_updated' => l10n(context).homeFavoriteSortByUpdateTime,
      '-datetime_browse' => l10n(context).homeFavoriteSortByReadTime,
      'mr' ||
      '-datetime_modifier' => l10n(context).homeFavoriteSortByFavoriteTime,
      _ => order,
    };
  }

  /// 本地模式把收藏时间的正序/倒序收进同一个子菜单。
  List<HazukiFrostedMenuOption<String>> _sortOptions(BuildContext context) {
    HazukiFrostedMenuOption<String> option(String order) =>
        HazukiFrostedMenuOption<String>(
          value: order,
          label: _sortLabel(context, order),
        );
    if (state.currentMode != FavoritePageMode.local) {
      return state.sortOrders.map(option).toList();
    }
    const savedOrders = ['savedNewest', 'savedOldest'];
    final saved = state.sortOrders.where(savedOrders.contains).toList();
    return [
      if (saved.isNotEmpty)
        HazukiFrostedMenuOption<String>.submenu(
          label: l10n(context).homeFavoriteSortByFavoriteTime,
          children: saved.map(option).toList(),
        ),
      ...state.sortOrders.where((o) => !savedOrders.contains(o)).map(option),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isLocalMode = state.currentMode == FavoritePageMode.local;
    return Row(
      key: const ValueKey<String>('favorite-appbar-actions'),
      mainAxisSize: MainAxisSize.min,
      children: [
        if (state.showModeToggle)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.08, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: TextButton.icon(
                key: ValueKey<FavoritePageMode>(state.currentMode),
                onPressed: onModeTogglePressed,
                icon: Icon(
                  isLocalMode
                      ? Icons.folder_copy_outlined
                      : Icons.cloud_outlined,
                  size: 18,
                ),
                label: Text(
                  isLocalMode
                      ? l10n(context).favoriteModeLocal
                      : l10n(context).favoriteModeCloud,
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ),
        if (state.showSort)
          HazukiFrostedMenuButton<String>(
            key: ValueKey((state.sourceKey, state.currentMode)),
            // 本地排序完全由 App 定义，不接受插件菜单声明。
            pluginMenu: isLocalMode
                ? null
                : SourcePluginMenuBinding(
                    menuId: 'favorites.cloud.sort',
                    sourceKey: state.sourceKey.isEmpty ? null : state.sourceKey,
                    gateway: sourcePlugins,
                    entries: state.menu.isEmpty ? null : state.menu,
                  ),
            tooltip: l10n(context).homeSortTooltip,
            selected: state.currentSortOrder,
            onSelected: onSortSelected,
            options: _sortOptions(context),
            icon: const Icon(Icons.sort_rounded),
          ),
        if (state.showCreateFolder)
          IconButton(
            tooltip: l10n(context).homeCreateFavoriteFolder,
            onPressed: onCreateFolderPressed,
            icon: const Icon(Icons.create_new_folder_outlined),
          ),
      ],
    );
  }
}
