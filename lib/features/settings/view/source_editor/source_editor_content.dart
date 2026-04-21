import 'package:flutter/material.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/widgets/widgets.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/javascript.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';
import 'package:re_highlight/styles/atom-one-light.dart';
import 'source_editor_controller.dart';

part 'source_editor_content_search.dart';
part 'source_editor_content_support.dart';

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
