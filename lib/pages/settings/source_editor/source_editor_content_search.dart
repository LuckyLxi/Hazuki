part of 'source_editor_content.dart';

extension _SourceEditorContentSearchActions on _SourceEditorContentState {
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
      transitionDuration:
          _SourceEditorContentState._searchDialogAnimationDuration,
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
    const maxLength = 80;
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
