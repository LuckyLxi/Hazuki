part of 'comments_page.dart';

class _CommentsBottomComposer extends StatelessWidget {
  const _CommentsBottomComposer({
    required this.replyToComment,
    required this.commentController,
    required this.commentFocusNode,
    required this.sendingComment,
    required this.onInputTap,
    required this.onSubmit,
    required this.onClearReply,
    this.bottomInset = 0,
  });

  final ComicCommentData? replyToComment;
  final TextEditingController commentController;
  final FocusNode commentFocusNode;
  final bool sendingComment;
  final VoidCallback onInputTap;
  final VoidCallback onSubmit;
  final VoidCallback onClearReply;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final hint = replyToComment == null
        ? l10n(context).commentsComposerHint
        : l10n(context).commentsReplyComposerHint(
            replyToComment!.userName.isEmpty
                ? l10n(context).commentsAnonymousUser
                : replyToComment!.userName,
          );
    final isFocused = commentFocusNode.hasFocus;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AnimatedCommentsReplyBanner(
              replyToComment: replyToComment,
              onClearReply: onClearReply,
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final expandedWidth = constraints.maxWidth;
                final collapsedWidth = math.min(
                  expandedWidth,
                  math.max(272.0, expandedWidth * 0.82),
                );
                final composerWidth = isFocused
                    ? expandedWidth
                    : collapsedWidth;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  width: composerWidth,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surface.withAlpha(176),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.outlineVariant.withAlpha(150),
                          ),
                        ),
                        child: _SuppressShowOnScreen(
                          child: TextField(
                            controller: commentController,
                            focusNode: commentFocusNode,
                            onTap: onInputTap,
                            onTapOutside: (_) => commentFocusNode.unfocus(),
                            scrollPadding: EdgeInsets.zero,
                            minLines: 1,
                            maxLines: 3,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => onSubmit(),
                            decoration: InputDecoration(
                              hintText: hint,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.only(
                                left: 16,
                                top: 10,
                                bottom: 10,
                                right: 4,
                              ),
                              isDense: true,
                              suffixIcon: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 4,
                                ),
                                child: FilledButton(
                                  onPressed: sendingComment ? null : onSubmit,
                                  style: FilledButton.styleFrom(
                                    minimumSize: Size.zero,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 0,
                                    ),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  child: Text(
                                    sendingComment
                                        ? l10n(context).commentsSending
                                        : l10n(context).commentsSend,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedCommentsReplyBanner extends StatefulWidget {
  const _AnimatedCommentsReplyBanner({
    required this.replyToComment,
    required this.onClearReply,
  });

  final ComicCommentData? replyToComment;
  final VoidCallback onClearReply;

  @override
  State<_AnimatedCommentsReplyBanner> createState() =>
      _AnimatedCommentsReplyBannerState();
}

class _AnimatedCommentsReplyBannerState
    extends State<_AnimatedCommentsReplyBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  ComicCommentData? _displayedReplyTo;

  @override
  void initState() {
    super.initState();
    _displayedReplyTo = widget.replyToComment;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 220),
      value: _displayedReplyTo == null ? 0.0 : 1.0,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void didUpdateWidget(covariant _AnimatedCommentsReplyBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.replyToComment;
    if (next != null) {
      setState(() {
        _displayedReplyTo = next;
      });
      unawaited(_controller.forward());
      return;
    }
    if (_displayedReplyTo != null && oldWidget.replyToComment != null) {
      unawaited(
        _controller.reverse().then((_) {
          if (mounted && widget.replyToComment == null) {
            setState(() {
              _displayedReplyTo = null;
            });
          }
        }),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final replyTo = _displayedReplyTo;
    if (replyTo == null) {
      return const SizedBox.shrink();
    }

    return ClipRect(
      child: FadeTransition(
        opacity: _animation,
        child: SizeTransition(
          sizeFactor: _animation,
          alignment: Alignment.topCenter,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.12),
              end: Offset.zero,
            ).animate(_animation),
            child: _CommentsReplyBanner(
              replyToComment: replyTo,
              onClearReply: widget.onClearReply,
            ),
          ),
        ),
      ),
    );
  }
}

class _CommentsReplyBanner extends StatelessWidget {
  const _CommentsReplyBanner({
    required this.replyToComment,
    required this.onClearReply,
  });

  final ComicCommentData? replyToComment;
  final VoidCallback onClearReply;

  @override
  Widget build(BuildContext context) {
    final replyTo = replyToComment;
    if (replyTo == null) {
      return const SizedBox.shrink();
    }

    final name = replyTo.userName.isEmpty
        ? l10n(context).commentsAnonymousUser
        : replyTo.userName;
    final preview = commentPreviewText(replyTo.content);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n(context).commentsReplyToUser(name),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                if (preview.isNotEmpty)
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n(context).commentsCancelReplyTooltip,
            onPressed: onClearReply,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}
