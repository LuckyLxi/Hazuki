import 'package:flutter/material.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/comment_filter_service.dart';

Future<void> showCommentFilterDialog(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) {
      return const _CommentFilterDialog();
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      // 换一个新的弹出/关闭动画，这里使用滑动+透明度
      return SlideTransition(
        position: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        ).drive(Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)),
        child: FadeTransition(opacity: animation, child: child),
      );
    },
  );
}

class _CommentFilterDialog extends StatefulWidget {
  const _CommentFilterDialog();

  @override
  State<_CommentFilterDialog> createState() => _CommentFilterDialogState();
}

class _CommentFilterDialogState extends State<_CommentFilterDialog> {
  late CommentFilterMode _mode;
  late List<String> _userKeywords;
  final _addController = TextEditingController();
  final _addFocusNode = FocusNode();
  final _pageController = PageController();

  @override
  void initState() {
    super.initState();
    final service = CommentFilterService.instance;
    _mode = service.mode;
    _userKeywords = List.of(service.userKeywords);
  }

  @override
  void dispose() {
    _addController.dispose();
    _addFocusNode.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await CommentFilterService.instance.save(
      userKeywords: _userKeywords,
      mode: _mode,
    );
  }

  void _addKeyword() {
    final word = _addController.text.trim();
    if (word.isEmpty || _userKeywords.contains(word)) {
      _addController.clear();
      return;
    }
    setState(() {
      _userKeywords.add(word);
      _addController.clear();
    });
  }

  void _removeKeyword(String word) {
    setState(() {
      _userKeywords.remove(word);
    });
  }

  // 截断超过7个字符的关键词
  String _truncate(String word) {
    if (word.runes.length > 7) {
      return '${String.fromCharCodes(word.runes.take(7))}...';
    }
    return word;
  }

  // 显示完整关键词并允许编辑，带动画效果
  void _showEditKeywordDialog(String word, int index) {
    final strings = AppLocalizations.of(context)!;
    final editController = TextEditingController(text: word);
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return AlertDialog(
          title: Text(strings.commentFilterEditKeywordTitle),
          content: TextField(
            controller: editController,
            autofocus: true,
            maxLines: null,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            FilledButton(
              onPressed: () {
                final newWord = editController.text.trim();
                if (newWord.isNotEmpty && newWord != word) {
                  setState(() {
                    if (!_userKeywords.contains(newWord)) {
                      _userKeywords[index] = newWord;
                    } else {
                      _userKeywords.removeAt(index);
                    }
                  });
                }
                Navigator.pop(context);
              },
              child: Text(MaterialLocalizations.of(context).saveButtonLabel),
            ),
          ],
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutBack,
            reverseCurve: Curves.easeInBack,
          ),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
    );
  }

  Widget _buildMainPage(
    AppLocalizations strings,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          strings.commentFilterModeLabel,
          style: theme.textTheme.labelLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<CommentFilterMode>(
          segments: [
            ButtonSegment(
              value: CommentFilterMode.collapse,
              label: Text(strings.commentFilterModeCollapse),
              icon: const Icon(Icons.unfold_less_rounded),
            ),
            ButtonSegment(
              value: CommentFilterMode.hide,
              label: Text(strings.commentFilterModeHide),
              icon: const Icon(Icons.visibility_off_outlined),
            ),
          ],
          selected: {_mode},
          onSelectionChanged: (selection) {
            setState(() => _mode = selection.first);
          },
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _addController,
          focusNode: _addFocusNode,
          decoration: InputDecoration(
            hintText: strings.commentFilterAddHint,
            isDense: true,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.add),
              onPressed: _addKeyword,
            ),
          ),
          onSubmitted: (_) {
            _addKeyword();
            _addFocusNode.requestFocus();
          },
        ),
        const SizedBox(height: 16),
        Text(
          strings.commentFilterUserKeywordsLabel,
          style: theme.textTheme.labelLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: InkWell(
            onTap: () {
              // 点击预览区域滑入关键词列表页
              _pageController.animateToPage(
                1,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: _userKeywords.isEmpty
                  ? Text(
                      strings.commentFilterNoUserKeywords,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    )
                  : Text(
                      // 最多显示4行，超过自动省略，每个词也限制7个字符
                      _userKeywords.map(_truncate).join('  •  '),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            strings.commentFilterPreviewHint,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKeywordsPage(
    AppLocalizations strings,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                _pageController.animateToPage(
                  0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              tooltip: strings.commentFilterBackTooltip,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                strings.commentFilterKeywordListTitle,
                style: theme.textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const Divider(),
        Expanded(
          child: _userKeywords.isEmpty
              ? Center(
                  child: Text(
                    strings.commentFilterNoUserKeywords,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _userKeywords.length,
                  itemBuilder: (context, index) {
                    final word = _userKeywords[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.5,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          title: Text(_truncate(word)),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _removeKeyword(word),
                          ),
                          onTap: () => _showEditKeywordDialog(word, index),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: Text(strings.commentFilterDialogTitle),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      content: SizedBox(
        width: 400,
        height: 480, // 弹窗上下长一点
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildMainPage(strings, theme, colorScheme),
            _buildKeywordsPage(strings, theme, colorScheme),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
        FilledButton(
          onPressed: () async {
            await _save();
            if (context.mounted) Navigator.of(context).pop();
          },
          child: Text(MaterialLocalizations.of(context).saveButtonLabel),
        ),
      ],
    );
  }
}
