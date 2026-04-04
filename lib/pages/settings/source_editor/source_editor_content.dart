import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/javascript.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';
import 'package:re_highlight/styles/atom-one-light.dart';

import '../../../l10n/app_localizations.dart';
import '../../../widgets/widgets.dart';
import 'source_editor_controller.dart';

class SourceEditorContent extends StatefulWidget {
  const SourceEditorContent({
    super.key,
    required this.strings,
    required this.controller,
    required this.saving,
    required this.inlineErrorText,
    required this.onSaveRequested,
  });

  final AppLocalizations strings;
  final SourceCodeEditingController controller;
  final bool saving;
  final String? inlineErrorText;
  final VoidCallback onSaveRequested;

  @override
  State<SourceEditorContent> createState() => _SourceEditorContentState();
}

class _SourceEditorContentState extends State<SourceEditorContent>
    with SingleTickerProviderStateMixin {
  static const Duration _searchDialogAnimationDuration = Duration(
    milliseconds: 240,
  );
  static const Duration _searchHighlightDuration = Duration(seconds: 5);

  final TextEditingController _searchController = TextEditingController();

  late final AnimationController _highlightAnimationController;
  late final Animation<double> _highlightOpacity;
  late final _SearchHighlightCodeLineController _editorController;
  _SearchHighlight? _activeHighlight;

  SourceCodeEditingController get _controller => widget.controller;
  AppLocalizations get _strings => widget.strings;

  @override
  void initState() {
    super.initState();
    _highlightAnimationController =
        AnimationController(vsync: this, duration: _searchHighlightDuration)
          ..addListener(_handleHighlightAnimationTick)
          ..addStatusListener(_handleHighlightAnimationStatusChanged);
    _highlightOpacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 12,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1), weight: 68),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: 0,
        ).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 20,
      ),
    ]).animate(_highlightAnimationController);
    _editorController = _SearchHighlightCodeLineController(
      delegate: _controller,
      highlightGetter: () => _activeHighlight,
      highlightOpacityGetter: () => _highlightOpacity.value,
    );
  }

  @override
  void dispose() {
    _highlightAnimationController
      ..removeListener(_handleHighlightAnimationTick)
      ..removeStatusListener(_handleHighlightAnimationStatusChanged)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleHighlightAnimationTick() {
    if (_activeHighlight == null) {
      return;
    }
    _editorController.forceRepaint();
  }

  void _handleHighlightAnimationStatusChanged(AnimationStatus status) {
    if (status != AnimationStatus.completed) {
      return;
    }
    setState(() {
      _activeHighlight = null;
    });
    _editorController.forceRepaint();
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      return;
    }
    final matches = _findMatches(query);
    if (!mounted) {
      return;
    }
    if (matches.isEmpty) {
      await showHazukiPrompt(
        context,
        _strings.sourceEditorSearchNoResult,
        isError: true,
      );
      return;
    }
    await _showSearchResults(matches, query);
  }

  List<_SourceSearchMatch> _findMatches(String query) {
    final matches = <_SourceSearchMatch>[];
    final normalizedQuery = query.toLowerCase();
    for (var i = 0; i < _controller.codeLines.length; i++) {
      final line = _controller.codeLines[i].text;
      final normalizedLine = line.toLowerCase();
      var searchStart = 0;
      while (true) {
        final foundIndex = normalizedLine.indexOf(normalizedQuery, searchStart);
        if (foundIndex == -1) {
          break;
        }
        matches.add(
          _SourceSearchMatch(
            lineIndex: i,
            columnIndex: foundIndex,
            lineText: line,
            matchLength: query.length,
          ),
        );
        searchStart = foundIndex + query.length;
      }
    }
    return matches;
  }

  Future<void> _showSearchResults(
    List<_SourceSearchMatch> matches,
    String query,
  ) async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: _searchDialogAnimationDuration,
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final theme = Theme.of(dialogContext);
        final colorScheme = theme.colorScheme;
        return SafeArea(
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 560,
                  maxHeight: 640,
                ),
                child: Container(
                  margin: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.24),
                        blurRadius: 28,
                        offset: const Offset(0, 18),
                      ),
                    ],
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.36),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
                        child: Text(
                          _strings.sourceEditorSearchResultCount(
                            matches.length,
                          ),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: matches.length,
                          separatorBuilder: (context, index) => Divider(
                            height: 1,
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.45,
                            ),
                          ),
                          itemBuilder: (context, index) {
                            final match = matches[index];
                            return ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 2,
                              ),
                              title: Text(
                                '第 ${match.lineIndex + 1} 行，第 ${match.columnIndex + 1} 列',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  _buildSnippet(match.lineText, query),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontFamily: 'monospace',
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              onTap: () {
                                Navigator.of(dialogContext).pop();
                                _jumpToMatch(match);
                              },
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: Text(
                              MaterialLocalizations.of(
                                dialogContext,
                              ).closeButtonLabel,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final scaleAnimation = Tween<double>(
          begin: 0.92,
          end: 1,
        ).animate(curvedAnimation);
        final slideAnimation = Tween<Offset>(
          begin: const Offset(0, 0.03),
          end: Offset.zero,
        ).animate(curvedAnimation);
        return FadeTransition(
          opacity: curvedAnimation,
          child: SlideTransition(
            position: slideAnimation,
            child: ScaleTransition(scale: scaleAnimation, child: child),
          ),
        );
      },
    );
  }

  String _buildSnippet(String line, String query) {
    final maxLength = 80;
    if (line.length <= maxLength) {
      return line.trim();
    }
    final foundIndex = line.toLowerCase().indexOf(query.toLowerCase());
    if (foundIndex == -1) {
      return '${line.substring(0, maxLength).trimRight()}...';
    }
    final start = (foundIndex - 24).clamp(0, line.length);
    final end = (foundIndex + query.length + 36).clamp(0, line.length);
    final prefix = start > 0 ? '...' : '';
    final suffix = end < line.length ? '...' : '';
    return '$prefix${line.substring(start, end).trim()}$suffix';
  }

  void _jumpToMatch(_SourceSearchMatch match) {
    final position = CodeLinePosition(
      index: match.lineIndex,
      offset: match.columnIndex,
    );
    _editorController.selection = CodeLineSelection.collapsed(
      index: match.lineIndex,
      offset: match.columnIndex,
    );
    _editorController.makePositionCenterIfInvisible(position);
    _setTemporaryHighlight(match);
  }

  void _setTemporaryHighlight(_SourceSearchMatch highlight) {
    _highlightAnimationController.stop();
    setState(() {
      _activeHighlight = _SearchHighlight(
        lineIndex: highlight.lineIndex,
        startOffset: highlight.columnIndex,
        endOffset: highlight.columnIndex + highlight.matchLength,
      );
    });
    _editorController.forceRepaint();
    _highlightAnimationController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final lineNumberStyle =
        theme.textTheme.bodyMedium?.copyWith(
          fontFamily: 'monospace',
          fontSize: 13.5,
          height: 1.5,
          letterSpacing: 0.1,
          color: colorScheme.onSurfaceVariant,
          fontFeatures: const [FontFeature.tabularFigures()],
        ) ??
        TextStyle(
          fontFamily: 'monospace',
          fontSize: 13.5,
          height: 1.5,
          color: colorScheme.onSurfaceVariant,
          fontFeatures: const [FontFeature.tabularFigures()],
        );
    final focusedLineNumberStyle = lineNumberStyle.copyWith(
      color: colorScheme.primary,
      fontWeight: FontWeight.w700,
    );
    final editorStyle = CodeEditorStyle(
      fontFamily: 'monospace',
      fontSize: 13.5,
      fontHeight: 1.5,
      textColor: colorScheme.onSurface,
      backgroundColor: colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.32,
      ),
      selectionColor: colorScheme.primary.withValues(alpha: 0.18),
      highlightColor: colorScheme.primaryContainer.withValues(alpha: 0.28),
      cursorColor: colorScheme.primary,
      cursorLineColor: colorScheme.primary.withValues(alpha: 0.08),
      codeTheme: CodeHighlightTheme(
        languages: {
          'javascript': CodeHighlightThemeMode(
            mode: langJavascript,
            maxSize: 512 * 1024,
            maxLineLength: 64 * 1024,
          ),
        },
        theme: _buildHighlightTheme(
          brightness: theme.brightness,
          textColor: colorScheme.onSurface,
        ),
      ),
    );

    final shortcutOverrideActions = {
      CodeShortcutSaveIntent: CallbackAction<CodeShortcutSaveIntent>(
        onInvoke: (intent) {
          widget.onSaveRequested();
          return null;
        },
      ),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              return Row(
                children: [
                  const _SourceEditorFileBadge(fileBadge: 'jm.js'),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: TextField(
                        controller: _searchController,
                        enabled: !widget.saving,
                        onSubmitted: (_) => _performSearch(),
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: _strings.sourceEditorSearchHint,
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: IconButton(
                            onPressed: widget.saving ? null : _performSearch,
                            icon: const Icon(Icons.arrow_forward_rounded),
                            tooltip: MaterialLocalizations.of(
                              context,
                            ).searchFieldLabel,
                          ),
                          isDense: true,
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHigh,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: colorScheme.outlineVariant.withValues(
                                alpha: 0.48,
                              ),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: colorScheme.outlineVariant.withValues(
                                alpha: 0.48,
                              ),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: colorScheme.primary),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _strings.sourceEditorLineCount(_controller.lineCount),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              );
            },
          ),
          if (widget.inlineErrorText != null) ...[
            const SizedBox(height: 12),
            _SourceEditorInlineErrorCard(message: widget.inlineErrorText!),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: RepaintBoundary(
              child: CodeEditor(
                controller: _editorController,
                autofocus: false,
                readOnly: widget.saving,
                wordWrap: false,
                autocompleteSymbols: false,
                showCursorWhenReadOnly: false,
                clipBehavior: Clip.antiAlias,
                chunkAnalyzer: const NonCodeChunkAnalyzer(),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.52),
                ),
                borderRadius: BorderRadius.circular(20),
                padding: const EdgeInsets.fromLTRB(14, 10, 18, 12),
                style: editorStyle,
                indicatorBuilder:
                    (context, editingController, chunkController, notifier) {
                      return Container(
                        color: colorScheme.surfaceContainerHigh.withValues(
                          alpha: 0.72,
                        ),
                        padding: const EdgeInsets.only(right: 8),
                        child: DefaultCodeLineNumber(
                          controller: editingController,
                          notifier: notifier,
                          minNumberCount: 2,
                          textStyle: lineNumberStyle,
                          focusedTextStyle: focusedLineNumberStyle,
                        ),
                      );
                    },
                sperator: Container(
                  width: 1,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.28),
                ),
                toolbarController: const _SourceEditorToolbarController(),
                shortcutOverrideActions: shortcutOverrideActions,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, TextStyle> _buildHighlightTheme({
    required Brightness brightness,
    required Color textColor,
  }) {
    final baseTheme = brightness == Brightness.dark
        ? atomOneDarkTheme
        : atomOneLightTheme;
    return {
      for (final entry in baseTheme.entries)
        entry.key: entry.value.copyWith(
          color: entry.key == 'root' ? textColor : entry.value.color,
          backgroundColor: Colors.transparent,
          fontFamily: 'monospace',
          fontSize: 13.5,
          height: 1.5,
        ),
    };
  }
}

class _SourceSearchMatch {
  const _SourceSearchMatch({
    required this.lineIndex,
    required this.columnIndex,
    required this.lineText,
    required this.matchLength,
  });

  final int lineIndex;
  final int columnIndex;
  final String lineText;
  final int matchLength;
}

class _SearchHighlight {
  const _SearchHighlight({
    required this.lineIndex,
    required this.startOffset,
    required this.endOffset,
  });

  final int lineIndex;
  final int startOffset;
  final int endOffset;
}

class _SearchHighlightCodeLineController
    extends CodeLineEditingControllerDelegate {
  _SearchHighlightCodeLineController({
    required super.delegate,
    required this.highlightGetter,
    required this.highlightOpacityGetter,
  });

  final _SearchHighlight? Function() highlightGetter;
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

class _StyledTextSegment {
  const _StyledTextSegment({required this.text, required this.style});

  final String text;
  final TextStyle? style;
}

class _SourceEditorToolbarController implements SelectionToolbarController {
  const _SourceEditorToolbarController();

  @override
  void hide(BuildContext context) {}

  @override
  void show({
    required BuildContext context,
    required CodeLineEditingController controller,
    required TextSelectionToolbarAnchors anchors,
    Rect? renderRect,
    required LayerLink layerLink,
    required ValueNotifier<bool> visibility,
  }) {
    final localizations = MaterialLocalizations.of(context);
    final items = <PopupMenuEntry<void>>[
      if (!controller.selection.isCollapsed)
        PopupMenuItem<void>(
          onTap: controller.cut,
          child: Text(localizations.cutButtonLabel),
        ),
      if (!controller.selection.isCollapsed)
        PopupMenuItem<void>(
          onTap: () {
            controller.copy();
          },
          child: Text(localizations.copyButtonLabel),
        ),
      PopupMenuItem<void>(
        onTap: controller.paste,
        child: Text(localizations.pasteButtonLabel),
      ),
      PopupMenuItem<void>(
        onTap: controller.selectAll,
        child: Text(localizations.selectAllButtonLabel),
      ),
    ];

    showMenu<void>(
      context: context,
      position: RelativeRect.fromLTRB(
        anchors.primaryAnchor.dx,
        anchors.primaryAnchor.dy,
        MediaQuery.sizeOf(context).width - anchors.primaryAnchor.dx,
        MediaQuery.sizeOf(context).height - anchors.primaryAnchor.dy,
      ),
      items: items,
    );
  }
}

class _SourceEditorInlineErrorCard extends StatelessWidget {
  const _SourceEditorInlineErrorCard({required this.message});

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

class _SourceEditorFileBadge extends StatelessWidget {
  const _SourceEditorFileBadge({required this.fileBadge});

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
