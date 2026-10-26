import 'package:flutter/material.dart';

import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/widgets/widgets.dart';

import '../support/comic_detail_plugin_tabs_controller.dart';
import 'comic_detail_view_primitives.dart';

/// 插件声明的详情页标签页，按区块顺序渲染文本与图片网格。
class ComicDetailPluginTab extends StatefulWidget {
  const ComicDetailPluginTab({
    super.key,
    required this.controller,
    required this.tabId,
    required this.sourceKey,
    required this.isActiveInTabView,
    required this.onOpenImage,
  });

  final ComicDetailPluginTabsController controller;
  final String tabId;
  final String sourceKey;
  final bool isActiveInTabView;
  final void Function(String url, String heroTag) onOpenImage;

  @override
  State<ComicDetailPluginTab> createState() => _ComicDetailPluginTabState();
}

class _ComicDetailPluginTabState extends State<ComicDetailPluginTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (!widget.isActiveInTabView) {
      return const SizedBox.expand();
    }
    final overlapHandle = NestedScrollView.sliverOverlapAbsorberHandleFor(
      context,
    );
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final state = widget.controller.stateOf(widget.tabId);
        Widget fill(Widget child) => CustomScrollView(
          physics: const ClampingScrollPhysics(),
          slivers: [
            SliverOverlapInjector(handle: overlapHandle),
            SliverFillRemaining(hasScrollBody: false, child: child),
          ],
        );
        switch (state.status) {
          case ComicDetailPluginTabStatus.loading:
            return fill(const ComicDetailLoadingView());
          case ComicDetailPluginTabStatus.failed:
            return fill(
              ComicDetailLoadErrorView(
                isTimeout: false,
                onRetry: () => widget.controller.retry(widget.tabId),
              ),
            );
          case ComicDetailPluginTabStatus.ready:
            if (state.blocks.isEmpty) {
              return fill(
                Center(child: Text(l10n(context).comicDetailPluginTabEmpty)),
              );
            }
            return _buildBlocks(context, overlapHandle, state.blocks);
        }
      },
    );
  }

  Widget _buildBlocks(
    BuildContext context,
    SliverOverlapAbsorberHandle overlapHandle,
    List<SourceDetailTabBlock> blocks,
  ) {
    final isDesktop = Theme.of(context).platform == TargetPlatform.windows;
    final padding = isDesktop ? 24.0 : 16.0;
    final spacing = isDesktop ? 12.0 : 8.0;
    final titleStyle = Theme.of(
      context,
    ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600);
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth =
            (constraints.maxWidth - padding * 2 - spacing * 2) / 3;
        final cacheWidth = (tileWidth * MediaQuery.devicePixelRatioOf(context))
            .round()
            .clamp(120, 640)
            .toInt();
        return CustomScrollView(
          key: PageStorageKey<String>(
            'comic-detail-plugin-tab-${widget.tabId}',
          ),
          physics: const ClampingScrollPhysics(),
          slivers: [
            SliverOverlapInjector(handle: overlapHandle),
            for (final (blockIndex, block) in blocks.indexed) ...[
              if (block.title.isNotEmpty)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(padding, padding, padding, 0),
                  sliver: SliverToBoxAdapter(
                    child: Text(block.title, style: titleStyle),
                  ),
                ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  padding,
                  block.title.isNotEmpty ? spacing : padding,
                  padding,
                  blockIndex == blocks.length - 1 ? padding : 0,
                ),
                sliver: switch (block) {
                  SourceDetailTextBlock(:final text) => SliverToBoxAdapter(
                    child: SelectableText(
                      text,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  SourceDetailImagesBlock(:final urls) => SliverGrid(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final url = urls[index];
                      final heroTag =
                          'comic-detail-plugin-tab-${widget.tabId}-'
                          '$blockIndex-$index-$url';
                      return _ComicDetailPluginImageTile(
                        url: url,
                        sourceKey: widget.sourceKey,
                        heroTag: heroTag,
                        cacheWidth: cacheWidth,
                        onTap: () => widget.onOpenImage(url, heroTag),
                      );
                    }, childCount: urls.length),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: spacing,
                      crossAxisSpacing: spacing,
                      childAspectRatio: 3 / 4,
                    ),
                  ),
                },
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ComicDetailPluginImageTile extends StatelessWidget {
  const _ComicDetailPluginImageTile({
    required this.url,
    required this.sourceKey,
    required this.heroTag,
    required this.cacheWidth,
    required this.onTap,
  });

  final String url;
  final String sourceKey;
  final String heroTag;
  final int cacheWidth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final placeholderColor = Theme.of(
      context,
    ).colorScheme.surfaceContainerHighest;
    return GestureDetector(
      onTap: onTap,
      child: Hero(
        tag: heroTag,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: HazukiCachedImage(
            url: url,
            sourceKey: sourceKey,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            cacheWidth: cacheWidth,
            loading: ColoredBox(color: placeholderColor),
            error: ColoredBox(
              color: placeholderColor,
              child: const Center(child: Icon(Icons.broken_image_outlined)),
            ),
          ),
        ),
      ),
    );
  }
}
