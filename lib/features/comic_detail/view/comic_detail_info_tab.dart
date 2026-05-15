import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/hazuki_source_service.dart';

import '../support/comic_detail_scope.dart';
import 'comic_detail_expandable_description.dart';
import 'comic_detail_meta.dart';
import 'comic_detail_view_primitives.dart';

class ComicDetailInfoTab extends StatelessWidget {
  const ComicDetailInfoTab({
    super.key,
    required this.details,
    required this.skeletonColor,
    required this.isActiveInTabView,
    required this.shouldAnimateResolvedContent,
  });

  final ComicDetailsData? details;
  final Color skeletonColor;
  final bool isActiveInTabView;
  final bool shouldAnimateResolvedContent;

  Widget _buildMetaSection(BuildContext context, ComicDetailsData details) {
    final actions = ComicDetailScope.of(context).actions;
    return ComicDetailMetaSection(
      details: details,
      showComicId: !isHazukiCopyMangaSourceKey(details.sourceKey),
      onCopyId: (id) => unawaited(actions.copyComicId(context, id)),
      onMetaValuePressed: (v) => actions.openSearchForKeyword(context, v),
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
      return CustomScrollView(
        key: const PageStorageKey<String>('comic-detail-info-tab-loading'),
        physics: const ClampingScrollPhysics(),
        slivers: [
          SliverOverlapInjector(handle: overlapHandle),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            sliver: SliverToBoxAdapter(
              child: _ComicDetailInfoSkeleton(skeletonColor: skeletonColor),
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
    final showComicId = !isHazukiCopyMangaSourceKey(resolvedDetails.sourceKey);
    final hasVisibleMeta =
        (showComicId && resolvedDetails.id.trim().isNotEmpty) ||
        resolvedDetails.tags.isNotEmpty;

    return CustomScrollView(
      key: const PageStorageKey<String>('comic-detail-info-tab'),
      physics: const ClampingScrollPhysics(),
      slivers: [
        SliverOverlapInjector(handle: overlapHandle),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: ComicDetailEntranceReveal(
              key: ValueKey<String>('comic-detail-info-${resolvedDetails.id}'),
              beginOffset: const Offset(0, 20),
              enabled: shouldAnimate,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (resolvedDetails.description.isNotEmpty) ...[
                    Text(
                      l10n(context).comicDetailSummary,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    ComicDetailExpandableDescription(
                      text: resolvedDetails.description,
                    ),
                  ],
                  if (hasVisibleMeta) ...[
                    const SizedBox(height: 12),
                    _buildMetaSection(context, resolvedDetails),
                  ],
                ],
              ),
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
