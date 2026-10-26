import 'package:hazuki/services/source/plugins/source_plugin_localization.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:hazuki/shared/favorites/favorite_folders_morph_dialog.dart';
import 'package:hazuki/shared/source_interaction/source_plugin_icons.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/models/hazuki_models.dart';

import '../support/comic_detail_scope.dart';
import 'comic_detail_view_primitives.dart';

class ComicDetailHeaderFavoriteRow extends StatelessWidget {
  const ComicDetailHeaderFavoriteRow({
    super.key,
    required this.details,
    required this.favoriteRowKey,
    required this.skeletonColor,
    required this.shouldAnimateInitialDetailReveal,
    this.isDesktop = false,
  });

  final ComicDetailsData? details;
  final GlobalKey favoriteRowKey;
  final Color skeletonColor;
  final bool shouldAnimateInitialDetailReveal;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final scope = ComicDetailScope.of(context);
    final favorite = scope.favorite;
    final theme = Theme.of(context);
    final detailsReady = details != null;
    final favoriteActive =
        favorite.favoriteOverride ?? details?.isFavorite ?? false;
    final stats = ComicDetailHeaderStatsRow(details: details);
    Widget reserveButtonHeight(Widget content) => SizedBox(
      width: double.infinity,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          // Reserve a button-sized row even before plugin stats resolve.
          // Measuring it also honors text scale, theme padding and the
          // minimum touch target size.
          Visibility(
            visible: false,
            maintainSize: true,
            maintainState: true,
            maintainAnimation: true,
            child: TextButton.icon(
              onPressed: null,
              style: comicDetailHeaderStatButtonStyle(theme),
              icon: const SizedBox.square(dimension: 16),
              label: const Text(' ', maxLines: 1),
            ),
          ),
          Positioned.fill(
            child: Align(alignment: Alignment.centerLeft, child: content),
          ),
        ],
      ),
    );

    if (isDesktop) {
      ButtonStyle buttonStyle(bool active) => OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        foregroundColor: active
            ? theme.colorScheme.onPrimaryContainer
            : theme.colorScheme.onSurface,
        backgroundColor: active
            ? theme.colorScheme.primaryContainer
            : Colors.transparent,
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      );
      return Column(
        key: favoriteRowKey,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 与下方操作按钮同宽，统计行不超出按钮区域；
          // 加载前后都按按钮高度占位，避免下方控件跳动。
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: reserveButtonHeight(
              detailsReady
                  ? stats
                  : ComicDetailSkeletonBlock(
                      color: skeletonColor,
                      width: 160,
                      height: 16,
                    ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: buttonStyle(favoriteActive),
            onPressed: detailsReady && !favorite.isBusy
                ? () => unawaited(
                    favorite.showFoldersDialog(
                      context,
                      details!,
                      (vm) => Theme(
                        data: scope.theme.buildDetailTheme(theme),
                        child: FavoriteFoldersMorphDialog(viewModel: vm),
                      ),
                    ),
                  )
                : null,
            icon: Icon(
              favoriteActive ? Icons.favorite : Icons.favorite_border,
              size: 18,
            ),
            label: Text(
              favoriteActive
                  ? l10n(context).comicDetailUnfavorite
                  : l10n(context).comicDetailFavorite,
            ),
          ),
        ],
      );
    }

    final reserveStatsHeight = theme.platform == TargetPlatform.android;
    final statsContent = detailsReady
        ? ComicDetailEntranceReveal(
            key: const ValueKey('comic-detail-stats'),
            beginOffset: Offset.zero,
            enabled: shouldAnimateInitialDetailReveal,
            child: stats,
          )
        : ComicDetailSkeletonBlock(
            color: skeletonColor,
            width: 160,
            height: 16,
          );
    return Padding(
      key: favoriteRowKey,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: AnimatedSlide(
        offset: Offset.zero,
        duration: Duration.zero,
        curve: Curves.easeOutCubic,
        child: reserveStatsHeight
            ? reserveButtonHeight(statsContent)
            : statsContent,
      ),
    );
  }
}

ButtonStyle comicDetailHeaderStatButtonStyle(ThemeData theme) =>
    TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      foregroundColor: theme.colorScheme.onSurfaceVariant,
      textStyle: theme.textTheme.bodySmall,
    );

/// 封面下方的插件统计行：单行显示，宽度不超过操作按钮区域，
/// 放不下时各项按比例截断。可点击项为无背景按钮。
class ComicDetailHeaderStatsRow extends StatelessWidget {
  const ComicDetailHeaderStatsRow({super.key, required this.details});

  final ComicDetailsData? details;

  @override
  Widget build(BuildContext context) {
    final scope = ComicDetailScope.of(context);
    final favorite = scope.favorite;
    final theme = Theme.of(context);
    final details = this.details;
    final locale = Localizations.localeOf(context).toLanguageTag();
    String statText(ComicHeaderStat stat) =>
        localizeSourcePluginText(stat.text, locale).trim();
    final stats =
        (favorite.headerStatsOverride ??
                details?.headerStats ??
                const <ComicHeaderStat>[])
            .where((stat) => statText(stat).isNotEmpty)
            .toList(growable: false);
    final statsStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    VoidCallback? onPressed(ComicHeaderStat stat, String text) {
      if (details == null) return null;
      final target = (stat.value ?? text).trim();
      return switch (stat.action) {
        ComicHeaderStatAction.none => null,
        ComicHeaderStatAction.plugin =>
          favorite.busyHeaderActionId != null
              ? null
              : () => unawaited(_runPluginAction(context, details, stat)),
        ComicHeaderStatAction.link => () => unawaited(
          launchUrl(Uri.parse(stat.url), mode: LaunchMode.externalApplication),
        ),
        ComicHeaderStatAction.search => () => unawaited(
          scope.actions.openTagValue(context, target),
        ),
        ComicHeaderStatAction.copy => () => unawaited(
          scope.actions.copyMetaValue(context, target),
        ),
      };
    }

    final children = <Widget>[];
    for (final stat in stats) {
      final text = statText(stat);
      final icon = sourcePluginIcon(stat.icon);
      final label = Text(text, maxLines: 1, overflow: TextOverflow.ellipsis);
      final Widget item;
      if (stat.action == ComicHeaderStatAction.none) {
        item = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: statsStyle?.color),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: DefaultTextStyle.merge(style: statsStyle, child: label),
              ),
            ],
          ),
        );
      } else {
        final style = comicDetailHeaderStatButtonStyle(theme);
        final callback = onPressed(stat, text);
        item = icon == null
            ? TextButton(onPressed: callback, style: style, child: label)
            : TextButton.icon(
                onPressed: callback,
                style: style,
                icon: Icon(icon, size: 16),
                label: label,
              );
      }
      if (children.isNotEmpty) children.add(const SizedBox(width: 10));
      children.add(Flexible(child: item));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }

  Future<void> _runPluginAction(
    BuildContext context,
    ComicDetailsData details,
    ComicHeaderStat stat,
  ) async {
    final scope = ComicDetailScope.of(context);
    final reload = await scope.favorite.runHeaderAction(context, details, stat);
    if (!reload) return;
    try {
      await scope.session.reloadDetails();
      scope.favorite.clearHeaderOverrides();
    } catch (_) {
      // 重载失败时保留当前显示，由插件下次操作再刷新。
    }
  }
}
