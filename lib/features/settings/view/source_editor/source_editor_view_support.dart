import 'dart:ui' show SemanticsRole;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:re_editor/re_editor.dart';

import 'source_editor_search_support.dart';

class SourceSearchHighlightCodeLineController
    extends CodeLineEditingControllerDelegate {
  SourceSearchHighlightCodeLineController({
    required super.delegate,
    required this.highlightGetter,
    required this.highlightOpacityGetter,
  });

  final SourceSearchHighlight? Function() highlightGetter;
  final double Function() highlightOpacityGetter;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    required int index,
    required TextSpan textSpan,
    required TextStyle style,
  }) {
    final highlightedSpan = super.buildTextSpan(
      context: context,
      index: index,
      textSpan: textSpan,
      style: style,
    );
    final highlight = highlightGetter();
    if (highlight == null || highlight.lineIndex != index) {
      return highlightedSpan;
    }
    final opacity = highlightOpacityGetter();
    if (opacity <= 0) {
      return highlightedSpan;
    }
    final colorScheme = Theme.of(context).colorScheme;
    final lineHighlightColor = colorScheme.tertiaryContainer.withValues(
      alpha: 0.22 * opacity,
    );
    final keywordHighlightColor = colorScheme.primary.withValues(
      alpha: 0.28 * opacity,
    );
    return _applyBackgroundHighlight(
      highlightedSpan,
      startOffset: highlight.startOffset,
      endOffset: highlight.endOffset,
      lineHighlightColor: lineHighlightColor,
      keywordHighlightColor: keywordHighlightColor,
    );
  }

  TextSpan _applyBackgroundHighlight(
    TextSpan textSpan, {
    required int startOffset,
    required int endOffset,
    required Color lineHighlightColor,
    required Color keywordHighlightColor,
  }) {
    final segments = <_StyledTextSegment>[];
    _collectTextSegments(textSpan, textSpan.style, segments);
    if (segments.isEmpty || startOffset >= endOffset) {
      return textSpan;
    }

    final rebuiltChildren = <InlineSpan>[];
    var cursor = 0;
    for (final segment in segments) {
      final segmentStart = cursor;
      final segmentEnd = cursor + segment.text.length;
      cursor = segmentEnd;

      if (segmentEnd <= startOffset || segmentStart >= endOffset) {
        rebuiltChildren.add(
          TextSpan(
            text: segment.text,
            style: _withBackgroundColor(segment.style, lineHighlightColor),
          ),
        );
        continue;
      }

      final localStart = (startOffset - segmentStart).clamp(
        0,
        segment.text.length,
      );
      final localEnd = (endOffset - segmentStart).clamp(0, segment.text.length);

      if (localStart > 0) {
        rebuiltChildren.add(
          TextSpan(
            text: segment.text.substring(0, localStart),
            style: _withBackgroundColor(segment.style, lineHighlightColor),
          ),
        );
      }

      if (localEnd > localStart) {
        rebuiltChildren.add(
          TextSpan(
            text: segment.text.substring(localStart, localEnd),
            style: _withBackgroundColor(segment.style, keywordHighlightColor),
          ),
        );
      }

      if (localEnd < segment.text.length) {
        rebuiltChildren.add(
          TextSpan(
            text: segment.text.substring(localEnd),
            style: _withBackgroundColor(segment.style, lineHighlightColor),
          ),
        );
      }
    }

    return TextSpan(style: textSpan.style, children: rebuiltChildren);
  }

  TextStyle _withBackgroundColor(TextStyle? style, Color backgroundColor) {
    return (style ?? const TextStyle()).copyWith(
      backgroundColor: backgroundColor,
    );
  }

  void _collectTextSegments(
    InlineSpan span,
    TextStyle? inheritedStyle,
    List<_StyledTextSegment> segments,
  ) {
    if (span is! TextSpan) {
      return;
    }
    final effectiveStyle = inheritedStyle?.merge(span.style) ?? span.style;
    final text = span.text;
    if (text != null && text.isNotEmpty) {
      segments.add(_StyledTextSegment(text: text, style: effectiveStyle));
    }
    final children = span.children;
    if (children == null || children.isEmpty) {
      return;
    }
    for (final child in children) {
      _collectTextSegments(child, effectiveStyle, segments);
    }
  }
}

class SourceEditorToolbarController implements SelectionToolbarController {
  OverlayEntry? _entry;
  LocalHistoryEntry? _historyEntry;
  ModalRoute<dynamic>? _historyRoute;
  final _menuKey = GlobalKey<_SourceEditorSelectionMenuState>();

  @override
  void hide(BuildContext context) {
    final entry = _entry;
    final historyEntry = _historyEntry;
    final historyRoute = _historyRoute;
    _entry = null;
    _historyEntry = null;
    _historyRoute = null;
    entry?.remove();
    entry?.dispose();
    if (historyRoute?.isActive ?? false) {
      historyEntry?.remove();
    }
  }

  @override
  void show({
    required BuildContext context,
    required CodeLineEditingController controller,
    required TextSelectionToolbarAnchors anchors,
    Rect? renderRect,
    required LayerLink layerLink,
    required ValueNotifier<bool> visibility,
  }) {
    // Internal toolbar updates must preserve the selection being adjusted.
    hide(context);
    final overlay = Overlay.of(context);
    final anchor = anchors.primaryAnchor.dx < 0 || anchors.primaryAnchor.dy < 0
        ? anchors.secondaryAnchor ?? anchors.primaryAnchor
        : anchors.primaryAnchor;
    final localizations = MaterialLocalizations.of(context);
    void dismiss({bool clearSelection = true}) {
      if (clearSelection && !controller.selection.isCollapsed) {
        controller.selection = CodeLineSelection.fromPosition(
          position: controller.selection.extent,
        );
      }
      final entry = _entry;
      if (entry == null) {
        return;
      }
      final state = _menuKey.currentState;
      if (state == null) {
        hide(context);
      } else {
        state.close(() {
          if (identical(_entry, entry)) {
            hide(context);
          }
        });
      }
    }

    final items = <PopupMenuEntry<void>>[
      if (!controller.selection.isCollapsed)
        _SourceEditorMenuItem(
          onTap: () {
            controller.cut();
            dismiss();
          },
          child: Text(localizations.cutButtonLabel),
        ),
      if (!controller.selection.isCollapsed)
        _SourceEditorMenuItem(
          onTap: () {
            controller.copy();
            dismiss();
          },
          child: Text(localizations.copyButtonLabel),
        ),
      _SourceEditorMenuItem(
        onTap: () async {
          final entry = _entry;
          final data = await Clipboard.getData(Clipboard.kTextPlain);
          if (entry == null ||
              !identical(_entry, entry) ||
              (_menuKey.currentState?.isClosing ?? true)) {
            return;
          }
          if (data?.text?.isNotEmpty ?? false) {
            controller.replaceSelection(data!.text!);
          }
          dismiss();
        },
        child: Text(localizations.pasteButtonLabel),
      ),
      _SourceEditorMenuItem(
        onTap: controller.selectAll,
        child: Text(localizations.selectAllButtonLabel),
      ),
    ];

    final overlayBox = overlay.context.findRenderObject()! as RenderBox;
    final themes = InheritedTheme.capture(from: context, to: overlay.context);
    _entry = OverlayEntry(
      builder: (_) => themes.wrap(
        _SourceEditorSelectionMenu(
          key: _menuKey,
          anchor: overlayBox.globalToLocal(anchor),
          items: items,
          visibility: visibility,
          onDismiss: dismiss,
        ),
      ),
    );
    final entry = _entry;
    _historyEntry = LocalHistoryEntry(
      impliesAppBarDismissal: false,
      onRemove: () {
        if (identical(_entry, entry)) {
          _historyEntry = null;
          dismiss();
        }
      },
    );
    _historyRoute = ModalRoute.of(context);
    _historyRoute?.addLocalHistoryEntry(_historyEntry!);
    overlay.insert(_entry!);
  }
}

// Keep PopupMenuItem's existing styling without popping the editor's route.
class _SourceEditorMenuItem extends PopupMenuItem<void> {
  const _SourceEditorMenuItem({required super.onTap, required super.child});

  @override
  PopupMenuItemState<void, _SourceEditorMenuItem> createState() =>
      _SourceEditorMenuItemState();
}

class _SourceEditorMenuItemState
    extends PopupMenuItemState<void, _SourceEditorMenuItem> {
  @override
  void handleTap() => widget.onTap?.call();
}

class _SourceEditorSelectionMenu extends StatefulWidget {
  const _SourceEditorSelectionMenu({
    super.key,
    required this.anchor,
    required this.items,
    required this.visibility,
    required this.onDismiss,
  });

  final Offset anchor;
  final List<PopupMenuEntry<void>> items;
  final ValueListenable<bool> visibility;
  final VoidCallback onDismiss;

  @override
  State<_SourceEditorSelectionMenu> createState() =>
      _SourceEditorSelectionMenuState();
}

class _SourceEditorSelectionMenuState extends State<_SourceEditorSelectionMenu>
    with SingleTickerProviderStateMixin {
  bool isClosing = false;
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  )..forward();
  late final CurvedAnimation _animation = CurvedAnimation(
    parent: _controller,
    curve: Curves.linear,
    reverseCurve: const Interval(0, 2 / 3),
  );

  void close(VoidCallback onClosed) {
    if (isClosing) {
      return;
    }
    setState(() => isClosing = true);
    _controller.reverse().whenCompleteOrCancel(() {
      if (mounted && _controller.isDismissed) {
        onClosed();
      }
    });
  }

  @override
  void dispose() {
    _animation.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final menuTheme = PopupMenuTheme.of(context);
    final unit = 1 / (widget.items.length + 1.5);
    // Match Flutter's popup menu dimensions, theme defaults and animation.
    final menu = ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 112, maxWidth: 280),
      child: IntrinsicWidth(
        stepWidth: 56,
        child: Semantics(
          role: SemanticsRole.menu,
          explicitChildNodes: true,
          label: MaterialLocalizations.of(context).popupMenuLabel,
          child: SingleChildScrollView(
            padding:
                menuTheme.menuPadding ??
                const EdgeInsets.symmetric(vertical: 8),
            child: ListBody(
              children: [
                for (var i = 0; i < widget.items.length; i++)
                  FadeTransition(
                    opacity: _animation.drive(
                      CurveTween(
                        curve: Interval(
                          (i + 1) * unit,
                          ((i + 2.5) * unit).clamp(0.0, 1.0),
                        ),
                      ),
                    ),
                    child: widget.items[i],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    return CustomSingleChildLayout(
      delegate: _SourceEditorMenuLayout(
        widget.anchor,
        MediaQuery.paddingOf(context),
      ),
      child: ValueListenableBuilder<bool>(
        valueListenable: widget.visibility,
        builder: (context, visible, child) => IgnorePointer(
          ignoring: !visible || isClosing,
          child: Opacity(opacity: visible ? 1 : 0, child: child),
        ),
        child: CodeEditorTapRegion(
          onTapOutside: (_) => widget.onDismiss(),
          child: AnimatedBuilder(
            animation: _animation,
            child: menu,
            builder: (context, child) => FadeTransition(
              opacity: _animation.drive(
                CurveTween(curve: const Interval(0, 1 / 3)),
              ),
              child: Material(
                type: MaterialType.card,
                shape:
                    menuTheme.shape ??
                    (theme.useMaterial3
                        ? const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(4)),
                          )
                        : null),
                color:
                    menuTheme.color ??
                    (theme.useMaterial3
                        ? theme.colorScheme.surfaceContainer
                        : null),
                elevation: menuTheme.elevation ?? (theme.useMaterial3 ? 3 : 8),
                shadowColor:
                    menuTheme.shadowColor ??
                    (theme.useMaterial3 ? theme.colorScheme.shadow : null),
                surfaceTintColor:
                    menuTheme.surfaceTintColor ??
                    (theme.useMaterial3 ? Colors.transparent : null),
                child: Align(
                  alignment: AlignmentDirectional.topEnd,
                  widthFactor: Interval(0, unit).transform(_animation.value),
                  heightFactor: Interval(
                    0,
                    unit * widget.items.length,
                  ).transform(_animation.value),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SourceEditorMenuLayout extends SingleChildLayoutDelegate {
  const _SourceEditorMenuLayout(this.anchor, this.padding);

  final Offset anchor;
  final EdgeInsets padding;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(
        Size(
          (constraints.maxWidth - padding.horizontal - 16).clamp(
            0,
            double.infinity,
          ),
          (constraints.maxHeight - padding.vertical - 16).clamp(
            0,
            double.infinity,
          ),
        ),
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) => Offset(
    anchor.dx.clamp(
      padding.left + 8,
      size.width - padding.right - childSize.width - 8,
    ),
    anchor.dy.clamp(
      padding.top + 8,
      size.height - padding.bottom - childSize.height - 8,
    ),
  );

  @override
  bool shouldRelayout(_SourceEditorMenuLayout oldDelegate) =>
      anchor != oldDelegate.anchor || padding != oldDelegate.padding;
}

class SourceEditorInlineErrorCard extends StatelessWidget {
  const SourceEditorInlineErrorCard({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onErrorContainer,
                height: 1.42,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SourceEditorFileBadge extends StatelessWidget {
  const SourceEditorFileBadge({super.key, required this.fileBadge});

  final String fileBadge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.javascript_rounded, size: 16, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            fileBadge,
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _StyledTextSegment {
  const _StyledTextSegment({required this.text, required this.style});

  final String text;
  final TextStyle? style;
}
