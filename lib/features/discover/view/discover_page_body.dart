import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:hazuki/shared/navigation_tags.dart';
import 'package:hazuki/widgets/widgets.dart';

import '../state/discover_page_controller.dart';
import 'discover_page_sections.dart';

class DiscoverPageBody extends StatelessWidget {
  const DiscoverPageBody({
    super.key,
    required this.controller,
    required this.scrollController,
    required this.headerItemCount,
    required this.headerItemBuilder,
    required this.onRefresh,
    this.onLoginPressed,
    required this.allowInitialLoad,
    required this.hideLoadingUntilInitialLoadAllowed,
    required this.comicDetailPageBuilder,
    required this.comicCoverHeroTagBuilder,
  });

  final DiscoverPageController controller;
  final ScrollController scrollController;
  final int headerItemCount;
  final IndexedWidgetBuilder headerItemBuilder;
  final Future<void> Function() onRefresh;
  final VoidCallback? onLoginPressed;
  final bool allowInitialLoad;
  final bool hideLoadingUntilInitialLoadAllowed;
  final ComicDetailPageBuilder comicDetailPageBuilder;
  final ComicHeroTagBuilder comicCoverHeroTagBuilder;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final visibleSectionCount = math.min(
          controller.visibleSectionCount,
          controller.sections.length,
        );
        final hasSections = visibleSectionCount > 0;

        return HazukiPullToRefresh(
          onRefresh: onRefresh,
          edgeOffset: 56,
          child: ListView.builder(
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            padding: const EdgeInsets.all(16),
            itemCount: hasSections
                ? visibleSectionCount + headerItemCount
                : headerItemCount + 1,
            itemBuilder: (context, index) {
              if (index < headerItemCount) {
                return headerItemBuilder(context, index);
              }
              if (!hasSections) {
                return DiscoverStateView(
                  initialLoading: controller.initialLoading,
                  refreshing: controller.refreshing,
                  sections: controller.sections,
                  errorMessage: controller.errorMessage,
                  sourceRuntimeState: controller.sourceRuntimeState,
                  showLoginRequired: controller.showLoginRequired,
                  allowInitialLoad: allowInitialLoad,
                  hideLoadingUntilInitialLoadAllowed:
                      hideLoadingUntilInitialLoadAllowed,
                  onRetry: onRefresh,
                  onLoginPressed: onLoginPressed,
                );
              }
              final sectionIndex = index - headerItemCount;
              return DiscoverSectionBlock(
                section: controller.sections[sectionIndex],
                sectionIndex: sectionIndex,
                comicDetailPageBuilder: comicDetailPageBuilder,
                comicCoverHeroTagBuilder: comicCoverHeroTagBuilder,
              );
            },
          ),
        );
      },
    );
  }
}
