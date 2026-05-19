part of 'comments_page.dart';

class _CommentsBodyList extends StatelessWidget {
  const _CommentsBodyList({
    required this.comments,
    required this.visibleComments,
    required this.hiddenCount,
    required this.initialLoading,
    required this.loadingMore,
    required this.errorMessage,
    required this.isTabView,
    required this.scrollController,
    required this.extraBottomPadding,
    required this.onRetry,
    required this.onScrollNotification,
    required this.commentBuilder,
  });

  final List<ComicCommentData> comments;
  final List<ComicCommentData> visibleComments;
  final int hiddenCount;
  final bool initialLoading;
  final bool loadingMore;
  final String? errorMessage;
  final bool isTabView;
  final ScrollController scrollController;
  final double extraBottomPadding;
  final VoidCallback onRetry;
  final void Function(ScrollNotification notification) onScrollNotification;
  final Widget Function(ComicCommentData comment, int index) commentBuilder;

  @override
  Widget build(BuildContext context) {
    final loadMoreFooter = loadingMore
        ? const HazukiLoadMoreFooter()
        : const SizedBox(height: 4);
    final listBottomPadding = EdgeInsets.only(bottom: 10 + extraBottomPadding);
    final contentKey = _contentKey();

    if (isTabView) {
      final overlapHandle = NestedScrollView.sliverOverlapAbsorberHandleFor(
        context,
      );
      return NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          onScrollNotification(notification);
          return false;
        },
        child: CustomScrollView(
          key: const PageStorageKey<String>('comic-detail-comments-tab'),
          physics: const _CommentsTabClampingScrollPhysics(),
          slivers: [
            SliverOverlapInjector(handle: overlapHandle),
            if (hiddenCount > 0)
              SliverToBoxAdapter(child: _HiddenCountBanner(count: hiddenCount)),
            if (comments.isNotEmpty)
              SliverPadding(
                padding: listBottomPadding,
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    if (index == visibleComments.length) {
                      return loadMoreFooter;
                    }
                    final isLastComment = index == visibleComments.length - 1;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        commentBuilder(visibleComments[index], index),
                        if (!isLastComment) const Divider(height: 1),
                      ],
                    );
                  }, childCount: visibleComments.length + 1),
                ),
              )
            else ...[
              SliverFillRemaining(
                hasScrollBody: false,
                child: _CommentsContentSwitcher(
                  child: _CommentsContent(
                    key: contentKey,
                    comments: comments,
                    initialLoading: initialLoading,
                    errorMessage: errorMessage,
                    onRetry: onRetry,
                    commentBuilder: commentBuilder,
                  ),
                ),
              ),
              SliverToBoxAdapter(child: loadMoreFooter),
            ],
          ],
        ),
      );
    }

    final content = _CommentsContent(
      key: contentKey,
      comments: comments,
      initialLoading: initialLoading,
      errorMessage: errorMessage,
      onRetry: onRetry,
      commentBuilder: commentBuilder,
    );
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        onScrollNotification(notification);
        return false;
      },
      child: comments.isNotEmpty
          ? CustomScrollView(
              controller: scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (hiddenCount > 0)
                  SliverToBoxAdapter(
                    child: _HiddenCountBanner(count: hiddenCount),
                  ),
                SliverPadding(
                  padding: listBottomPadding,
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      if (index == visibleComments.length) {
                        return loadMoreFooter;
                      }
                      final isLastComment = index == visibleComments.length - 1;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          commentBuilder(visibleComments[index], index),
                          if (!isLastComment) const Divider(height: 1),
                        ],
                      );
                    }, childCount: visibleComments.length + 1),
                  ),
                ),
              ],
            )
          : ListView(
              controller: scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: listBottomPadding,
              children: [
                _CommentsContentSwitcher(child: content),
                loadMoreFooter,
              ],
            ),
    );
  }

  Key _contentKey() {
    if (initialLoading) {
      return const ValueKey('loading');
    }
    if (errorMessage != null && comments.isEmpty) {
      return const ValueKey('error');
    }
    if (comments.isEmpty) {
      return const ValueKey('empty');
    }
    return const ValueKey('list');
  }
}

class _CommentsContentSwitcher extends StatelessWidget {
  const _CommentsContentSwitcher({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeOutCubic,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.topCenter,
          children: <Widget>[
            ...previousChildren,
            ...<Widget?>[currentChild].whereType<Widget>(),
          ],
        );
      },
      child: child,
    );
  }
}

class _CommentsContent extends StatelessWidget {
  const _CommentsContent({
    super.key,
    required this.comments,
    required this.initialLoading,
    required this.errorMessage,
    required this.onRetry,
    required this.commentBuilder,
  });

  final List<ComicCommentData> comments;
  final bool initialLoading;
  final String? errorMessage;
  final VoidCallback onRetry;
  final Widget Function(ComicCommentData comment, int index) commentBuilder;

  @override
  Widget build(BuildContext context) {
    if (initialLoading) {
      return Container(
        key: const ValueKey('loading'),
        padding: const EdgeInsets.only(top: 100),
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const HazukiSandyLoadingIndicator(size: 144),
            const SizedBox(height: 10),
            Text(l10n(context).commonLoading),
          ],
        ),
      );
    }

    if (errorMessage != null && comments.isEmpty) {
      return Container(
        key: const ValueKey('error'),
        padding: const EdgeInsets.only(top: 80),
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(errorMessage!, textAlign: TextAlign.center),
            ),
            FilledButton(
              onPressed: onRetry,
              child: Text(l10n(context).commonRetry),
            ),
          ],
        ),
      );
    }

    if (comments.isEmpty) {
      return Container(
        key: const ValueKey('empty'),
        padding: const EdgeInsets.only(top: 80),
        alignment: Alignment.topCenter,
        child: Text(l10n(context).commentsEmpty),
      );
    }

    return ListView.separated(
      key: const ValueKey('list'),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: comments.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) => commentBuilder(comments[index], index),
    );
  }
}

class _HiddenCountBanner extends StatelessWidget {
  const _HiddenCountBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        l10n(context).commentFilterHiddenBanner('$count'),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
