import 'package:flutter/material.dart';

import 'package:hazuki/features/reader/support/reader_callbacks.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/shared/comments/comments_interaction_state.dart';

class ReaderCommentsSheet extends StatefulWidget {
  const ReaderCommentsSheet({
    super.key,
    required this.comicId,
    required this.subId,
    required this.chapterId,
    required this.commentsWidgetBuilder,
    this.interactionState,
    this.sourceKey = '',
  });

  final String comicId;
  final String? subId;
  final String chapterId;
  final String sourceKey;
  final ReaderCommentsWidgetBuilder commentsWidgetBuilder;
  final CommentsInteractionState? interactionState;

  @override
  State<ReaderCommentsSheet> createState() => _ReaderCommentsSheetState();
}

class _ReaderCommentsSheetState extends State<ReaderCommentsSheet> {
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  bool _sheetAtFullHeight = false;
  bool _expandingToFullscreen = false;

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  Future<void> _expandToFullscreen() async {
    if (!_sheetController.isAttached ||
        _sheetAtFullHeight ||
        _expandingToFullscreen) {
      return;
    }
    _expandingToFullscreen = true;
    try {
      await _sheetController.animateTo(
        1,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    } finally {
      _expandingToFullscreen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (notification) {
        final nextAtFullHeight = notification.extent >= 0.98;
        if (nextAtFullHeight != _sheetAtFullHeight) {
          setState(() {
            _sheetAtFullHeight = nextAtFullHeight;
          });
        }
        return false;
      },
      child: DraggableScrollableSheet(
        controller: _sheetController,
        initialChildSize: 0.64,
        minChildSize: 0.64,
        maxChildSize: 1,
        shouldCloseOnMinExtent: false,
        expand: false,
        builder: (context, scrollController) {
          return DecoratedBox(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.24),
                  blurRadius: 28,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              child: SafeArea(
                top: _sheetAtFullHeight,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Center(
                                  child: Container(
                                    width: 38,
                                    height: 4,
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: cs.onSurfaceVariant.withValues(
                                        alpha: 0.28,
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                ),
                                Text(
                                  l10n(context).commentsTitle,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: l10n(context).commonClose,
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: cs.outlineVariant.withValues(alpha: 0.48),
                    ),
                    Expanded(
                      child: widget.commentsWidgetBuilder(
                        comicId: widget.comicId,
                        subId: widget.subId,
                        chapterId: widget.chapterId,
                        sourceKey: widget.sourceKey,
                        scrollController: scrollController,
                        onRequestTabFullscreen: _expandToFullscreen,
                        interactionState: widget.interactionState,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
