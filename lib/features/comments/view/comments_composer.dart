part of 'comments_page.dart';

double resolveCommentsSafeBottomInset({
  required double observedSafeBottom,
  required double? lastCurrentRouteSafeBottom,
  required bool routeIsCurrent,
  required bool preserveAfterRouteCover,
}) {
  if ((routeIsCurrent && !preserveAfterRouteCover) ||
      lastCurrentRouteSafeBottom == null) {
    return observedSafeBottom;
  }
  return lastCurrentRouteSafeBottom;
}

class _KeyboardAwareCommentsBody extends StatelessWidget {
  const _KeyboardAwareCommentsBody({
    required this.useKeyboardInset,
    required this.child,
  });

  final bool useKeyboardInset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Keep the list above the IME when its parent does not resize itself.
    // This layout-only update preserves the expensive list child's element.
    return Padding(
      padding: EdgeInsets.only(
        bottom:
            MediaQuery.viewPaddingOf(context).bottom +
            (useKeyboardInset ? MediaQuery.viewInsetsOf(context).bottom : 0),
      ),
      child: child,
    );
  }
}

class _KeyboardAwareCommentsComposer extends StatefulWidget {
  const _KeyboardAwareCommentsComposer({
    required this.isFocused,
    required this.useKeyboardInset,
    required this.bottomMargin,
    required this.child,
  });

  final bool isFocused;
  final bool useKeyboardInset;
  final double bottomMargin;
  final Widget child;

  @override
  State<_KeyboardAwareCommentsComposer> createState() =>
      _KeyboardAwareCommentsComposerState();
}

class _KeyboardAwareCommentsComposerState
    extends State<_KeyboardAwareCommentsComposer> {
  double? _lastCurrentRouteSafeBottom;
  bool _preserveSafeBottomAfterRouteCover = false;

  @override
  Widget build(BuildContext context) {
    final observedSafeBottom = MediaQuery.paddingOf(context).bottom;
    final rawKeyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final routeIsCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    if (!routeIsCurrent) {
      _preserveSafeBottomAfterRouteCover = true;
    } else if (rawKeyboardInset > 0 ||
        observedSafeBottom >= (_lastCurrentRouteSafeBottom ?? 0)) {
      _preserveSafeBottomAfterRouteCover = false;
    }
    final safeBottom = resolveCommentsSafeBottomInset(
      observedSafeBottom: observedSafeBottom,
      lastCurrentRouteSafeBottom: _lastCurrentRouteSafeBottom,
      routeIsCurrent: routeIsCurrent,
      preserveAfterRouteCover: _preserveSafeBottomAfterRouteCover,
    );
    if ((routeIsCurrent && !_preserveSafeBottomAfterRouteCover) ||
        _lastCurrentRouteSafeBottom == null) {
      _lastCurrentRouteSafeBottom = observedSafeBottom;
    }
    final keyboardInset = widget.useKeyboardInset ? rawKeyboardInset : 0.0;
    // Keep the keyboard's per-frame inset updates inside the composer subtree.
    // Rebuilding the comments list for every IME animation frame is expensive,
    // especially when comments include images or expanded replies.
    return Positioned(
      left: widget.isFocused && widget.useKeyboardInset ? 10.0 : 16.0,
      right: widget.isFocused && widget.useKeyboardInset ? 10.0 : 16.0,
      bottom: safeBottom + widget.bottomMargin + keyboardInset,
      child: widget.child,
    );
  }
}

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
    final replyAttribution = replyToComment == null
        ? null
        : parseCommentUserAttribution(replyToComment!.userName);
    final hint = replyToComment == null
        ? l10n(context).commentsComposerHint
        : l10n(context).commentsReplyComposerHint(
            replyToComment!.userName.isEmpty
                ? l10n(context).commentsAnonymousUser
                : replyAttribution!.replyTo == null
                ? replyAttribution.author
                : l10n(context).commentsReplyAttribution(
                    replyAttribution.author,
                    replyAttribution.replyTo!,
                  ),
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
                  child: _CommentsComposerGlassSurface(
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
                                fixedSize: const Size.square(40),
                                minimumSize: const Size.square(40),
                                padding: EdgeInsets.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: Tooltip(
                                message: sendingComment
                                    ? l10n(context).commentsSending
                                    : l10n(context).commentsSend,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 180),
                                  switchInCurve: Curves.easeOutCubic,
                                  switchOutCurve: Curves.easeInCubic,
                                  child: sendingComment
                                      ? const SizedBox.square(
                                          key: ValueKey<String>(
                                            'sending-indicator',
                                          ),
                                          dimension: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          key: ValueKey<String>('send-icon'),
                                          Icons.send_rounded,
                                          size: 20,
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

class _CommentsComposerGlassSurface extends StatelessWidget {
  const _CommentsComposerGlassSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(24);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: hazukiSearchBoxBackgroundColor(context),
        borderRadius: radius,
        border: Border.fromBorderSide(hazukiSearchBoxOutlineSide(context)),
      ),
      child: child,
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

    final attribution = parseCommentUserAttribution(replyTo.userName);
    final name = replyTo.userName.isEmpty
        ? l10n(context).commentsAnonymousUser
        : attribution.replyTo == null
        ? attribution.author
        : l10n(
            context,
          ).commentsReplyAttribution(attribution.author, attribution.replyTo!);
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
