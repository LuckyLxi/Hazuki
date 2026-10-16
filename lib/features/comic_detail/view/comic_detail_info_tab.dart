import 'package:hazuki/shared/source_presentation.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/models/hazuki_models.dart';

import '../support/comic_detail_scope.dart';
import 'comic_detail_expandable_description.dart';
import 'comic_detail_meta.dart';
import 'comic_detail_view_primitives.dart';

class ComicDetailInfoTab extends StatelessWidget {
  const ComicDetailInfoTab({
    super.key,
    required this.details,
    this.error,
    this.hasTimedOut = false,
    this.isRetrying = false,
    this.onRetry,
    required this.skeletonColor,
    required this.isActiveInTabView,
    required this.shouldAnimateResolvedContent,
    this.isDesktop = false,
  });

  final ComicDetailsData? details;
  final Object? error;
  final bool hasTimedOut;
  final bool isRetrying;
  final VoidCallback? onRetry;
  final Color skeletonColor;
  final bool isActiveInTabView;
  final bool shouldAnimateResolvedContent;
  final bool isDesktop;

  Widget _buildMetaSection(BuildContext context, ComicDetailsData details) {
    final actions = ComicDetailScope.of(context).actions;
    return ComicDetailMetaSection(
      details: details,
      useMobileStyle: !isDesktop,
      showComicId:
          sourceButton(
            details.sourceKey,
            'copyComicId',
            SourcePluginButtonLocation.comicDetailInfo,
            context: context,
          ) !=
          null,
      onCopyId: (id) => unawaited(actions.copyComicId(context, id)),
      onTagValuePressed: (v) => unawaited(actions.openTagValue(context, v)),
      onMetaValueLongPress: (v) => unawaited(actions.copyMetaValue(context, v)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isActiveInTabView) {
      return const SizedBox.expand();
    }
    final overlapHandle = NestedScrollView.sliverOverlapAbsorberHandleFor(
      context,
    );
    if (details == null) {
      final error = this.error;
      return CustomScrollView(
        key: const PageStorageKey<String>('comic-detail-info-tab-loading'),
        physics: const ClampingScrollPhysics(),
        slivers: [
          SliverOverlapInjector(handle: overlapHandle),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            sliver: SliverToBoxAdapter(
              child: error == null && !hasTimedOut
                  ? _ComicDetailInfoSkeleton(skeletonColor: skeletonColor)
                  : ComicDetailLoadErrorView(
                      isTimeout: hasTimedOut || error is TimeoutException,
                      isRetrying: isRetrying,
                      onRetry: onRetry,
                    ),
            ),
          ),
        ],
      );
    }

    final resolvedDetails = details!;
    // Entrance animation must only play once per page lifetime. The flag lives
    // on the UiState controller (page-owned) — same lifetime as the previous
    // local _hasAnimated field on InfoTab's State. markInfoEntranceAnimated()
    // does NOT call notifyListeners(), matching the original (no rebuild).
    final uiState = ComicDetailScope.of(context).uiState;
    final shouldAnimate =
        shouldAnimateResolvedContent && !uiState.hasInfoEntranceAnimated;
    if (shouldAnimate) {
      uiState.markInfoEntranceAnimated();
    }
    final showComicId =
        sourceButton(
          resolvedDetails.sourceKey,
          'copyComicId',
          SourcePluginButtonLocation.comicDetailInfo,
          context: context,
        ) !=
        null;
    final hasVisibleMeta =
        (showComicId && resolvedDetails.id.trim().isNotEmpty) ||
        resolvedDetails.infoFields.any((field) => field.values.isNotEmpty);

    return CustomScrollView(
      key: const PageStorageKey<String>('comic-detail-info-tab'),
      physics: const ClampingScrollPhysics(),
      slivers: [
        SliverOverlapInjector(handle: overlapHandle),
        SliverPadding(
          padding: isDesktop
              ? const EdgeInsets.all(24)
              : const EdgeInsets.fromLTRB(23, 22, 23, 24),
          sliver: SliverToBoxAdapter(
            child: ComicDetailEntranceReveal(
              key: ValueKey<String>('comic-detail-info-${resolvedDetails.id}'),
              beginOffset: isDesktop ? const Offset(0, 20) : Offset.zero,
              enabled: shouldAnimate,
              child: isDesktop
                  ? _buildDesktopInfo(context, resolvedDetails, hasVisibleMeta)
                  : _buildMobileInfo(context, resolvedDetails, hasVisibleMeta),
            ),
          ),
        ),
        const SliverFillRemaining(
          hasScrollBody: false,
          child: SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildMobileInfo(
    BuildContext context,
    ComicDetailsData details,
    bool hasVisibleMeta,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (details.description.isNotEmpty) ...[
          Text(
            l10n(context).comicDetailSummary,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          DefaultTextStyle.merge(
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.9,
            ),
            child: ComicDetailExpandableDescription(text: details.description),
          ),
        ],
        if (details.description.isNotEmpty && hasVisibleMeta)
          Padding(
            padding: const EdgeInsets.only(top: 22, bottom: 4),
            child: Divider(
              height: 1,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
        if (hasVisibleMeta) _buildMetaSection(context, details),
      ],
    );
  }

  Widget _buildDesktopInfo(
    BuildContext context,
    ComicDetailsData details,
    bool hasVisibleMeta,
  ) {
    final theme = Theme.of(context);
    Widget card(Widget child) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: child,
    );
    final summary = details.description.isEmpty
        ? null
        : card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n(context).comicDetailSummary,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                ComicDetailExpandableDescription(text: details.description),
              ],
            ),
          );
    final metadata = hasVisibleMeta
        ? card(_buildMetaSection(context, details))
        : null;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 860 &&
            summary != null &&
            metadata != null) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: summary),
              const SizedBox(width: 20),
              Expanded(flex: 6, child: metadata),
            ],
          );
        }
        return Column(
          children: [
            ?summary,
            if (summary != null && metadata != null) const SizedBox(height: 20),
            ?metadata,
          ],
        );
      },
    );
  }
}

class _ComicDetailInfoSkeleton extends StatelessWidget {
  const _ComicDetailInfoSkeleton({required this.skeletonColor});

  final Color skeletonColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ComicDetailSkeletonBlock(
          color: skeletonColor,
          width: 92,
          height: 18,
          radius: 9,
        ),
        const SizedBox(height: 14),
        ComicDetailSkeletonBlock(color: skeletonColor, height: 16, radius: 8),
        const SizedBox(height: 10),
        ComicDetailSkeletonBlock(
          color: skeletonColor,
          width: MediaQuery.sizeOf(context).width * 0.72,
          height: 16,
          radius: 8,
        ),
        const SizedBox(height: 10),
        ComicDetailSkeletonBlock(
          color: skeletonColor,
          width: MediaQuery.sizeOf(context).width * 0.54,
          height: 16,
          radius: 8,
        ),
        const SizedBox(height: 18),
        ...List<Widget>.generate(
          4,
          (index) => Padding(
            padding: EdgeInsets.only(bottom: index == 3 ? 0 : 10),
            child: ComicDetailSkeletonBlock(
              color: skeletonColor,
              width:
                  MediaQuery.sizeOf(context).width *
                  (index.isEven ? 0.9 : 0.76),
              height: 16,
              radius: 8,
            ),
          ),
        ),
      ],
    );
  }
}
