import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/app/service_locator.dart';
import 'package:hazuki/services/comment_filter_service.dart';

Future<void> showCommentFilterDialog(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.68),
    transitionDuration: const Duration(milliseconds: 380),
    pageBuilder: (context, animation, secondaryAnimation) {
      return const _CommentFilterSheet();
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final screenWidth = MediaQuery.sizeOf(context).width;
      final isWide = screenWidth >= 600;
      if (isWide) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return ScaleTransition(
          scale: curved.drive(Tween(begin: 0.92, end: 1.0)),
          child: FadeTransition(opacity: curved, child: child),
        );
      }
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutQuart,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: curved.drive(
          Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero),
        ),
        child: child,
      );
    },
  );
}

class _CommentFilterSheet extends StatefulWidget {
  const _CommentFilterSheet();

  @override
  State<_CommentFilterSheet> createState() => _CommentFilterSheetState();
}

class _CommentFilterSheetState extends State<_CommentFilterSheet>
    with SingleTickerProviderStateMixin {
  late CommentFilterMode _mode;
  late List<String> _userKeywords;
  final _addController = TextEditingController();
  final _addFocusNode = FocusNode();
  String? _addKeywordError;

  // 关键词列表展开/收起
  bool _keywordsExpanded = false;

  @override
  void initState() {
    super.initState();
    final service = sl<CommentFilterService>();
    _mode = service.mode;
    _userKeywords = List.of(service.userKeywords);
  }

  @override
  void dispose() {
    _addController.dispose();
    _addFocusNode.dispose();
    super.dispose();
  }

  Future<void> _save({bool includePendingKeyword = false}) async {
    if (includePendingKeyword) {
      final pendingKeyword = _addController.text.trim();
      if (pendingKeyword.isNotEmpty &&
          !_userKeywords.contains(pendingKeyword)) {
        _userKeywords.add(pendingKeyword);
      }
    }
    await sl<CommentFilterService>().save(
      userKeywords: _userKeywords,
      mode: _mode,
    );
  }

  Future<void> _setMode(CommentFilterMode mode) async {
    if (_mode == mode) {
      return;
    }
    setState(() => _mode = mode);
    await _save();
  }

  void _addKeyword() {
    final strings = AppLocalizations.of(context)!;
    final word = _addController.text.trim();
    if (word.isEmpty) {
      setState(() => _addKeywordError = strings.commentFilterEmptyKeywordError);
      _addFocusNode.requestFocus();
      return;
    }
    if (_userKeywords.contains(word)) {
      _addController.clear();
      setState(() => _addKeywordError = null);
      return;
    }
    setState(() {
      _userKeywords.add(word);
      _addController.clear();
      _addKeywordError = null;
    });
  }

  void _removeKeyword(String word) async {
    final shouldRemove = await _showRemoveKeywordDialog(word);
    if (!mounted || shouldRemove != true) {
      return;
    }
    setState(() => _userKeywords.remove(word));
  }

  Future<bool?> _showRemoveKeywordDialog(String word) {
    final strings = AppLocalizations.of(context)!;
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _RemoveKeywordDialog(strings: strings, keyword: word);
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        );
        return ScaleTransition(
          scale: curved.drive(Tween(begin: 0.88, end: 1.0)),
          child: FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          ),
        );
      },
    );
  }

  void _showEditKeywordDialog(String word, int index) {
    final strings = AppLocalizations.of(context)!;
    final editController = TextEditingController(text: word);
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _EditKeywordDialog(
          strings: strings,
          editController: editController,
          onSave: (newWord) {
            if (newWord.isNotEmpty && newWord != word) {
              setState(() {
                if (!_userKeywords.contains(newWord)) {
                  _userKeywords[index] = newWord;
                } else {
                  _userKeywords.removeAt(index);
                }
              });
            }
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        );
        return ScaleTransition(
          scale: curved.drive(Tween(begin: 0.88, end: 1.0)),
          child: FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mediaSize = MediaQuery.sizeOf(context);
    final mediaPadding = MediaQuery.paddingOf(context);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final sheetColor = colorScheme.surfaceContainerLow;

    final screenWidth = mediaSize.width;
    final isWide = screenWidth >= 600;
    final sheetWidth = isWide ? 480.0 : double.infinity;
    final sheetRadius = isWide
        ? BorderRadius.circular(20)
        : const BorderRadius.vertical(top: Radius.circular(24));
    final sheetAlignment = isWide ? Alignment.center : Alignment.bottomCenter;
    final availableHeight =
        (mediaSize.height - keyboardInset - mediaPadding.top - 12)
            .clamp(240.0, mediaSize.height)
            .toDouble();
    final baseMaxHeight = mediaSize.height * 0.85;
    final maxSheetHeight = availableHeight < baseMaxHeight
        ? availableHeight
        : baseMaxHeight;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Align(
        alignment: sheetAlignment,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: sheetWidth,
            constraints: BoxConstraints(maxHeight: maxSheetHeight),
            decoration: BoxDecoration(
              color: sheetColor,
              borderRadius: sheetRadius,
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 拖拽指示条（仅窄屏）
                  if (!isWide)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 4),
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.28,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  // 标题栏
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 8, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            strings.commentFilterDialogTitle,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).closeButtonLabel,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 过滤模式
                          Text(
                            strings.commentFilterModeLabel,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _FilterModeSlider(
                            mode: _mode,
                            colorScheme: colorScheme,
                            theme: theme,
                            collapseLabel: strings.commentFilterModeCollapse,
                            hideLabel: strings.commentFilterModeHide,
                            onChanged: (mode) => unawaited(_setMode(mode)),
                          ),
                          const SizedBox(height: 20),
                          // 添加关键词
                          Text(
                            strings.commentFilterUserKeywordsLabel,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _addController,
                                  focusNode: _addFocusNode,
                                  decoration: InputDecoration(
                                    hintText: strings.commentFilterAddHint,
                                    errorText: _addKeywordError,
                                    isDense: true,
                                    filled: true,
                                    fillColor: colorScheme.surfaceContainer,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: colorScheme.primary,
                                        width: 1.5,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                  ),
                                  onSubmitted: (_) {
                                    _addKeyword();
                                    _addFocusNode.requestFocus();
                                  },
                                  onChanged: (_) {
                                    if (_addKeywordError != null) {
                                      setState(() => _addKeywordError = null);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.tonal(
                                onPressed: _addKeyword,
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(48, 48),
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Icon(Icons.add),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          // 关键词 chips
                          AnimatedCrossFade(
                            duration: const Duration(milliseconds: 260),
                            crossFadeState: _userKeywords.isEmpty
                                ? CrossFadeState.showFirst
                                : CrossFadeState.showSecond,
                            firstChild: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                strings.commentFilterNoUserKeywords,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            secondChild: _KeywordChipsSection(
                              keywords: _userKeywords,
                              expanded: _keywordsExpanded,
                              colorScheme: colorScheme,
                              theme: theme,
                              onToggleExpand: () => setState(
                                () => _keywordsExpanded = !_keywordsExpanded,
                              ),
                              onEdit: _showEditKeywordDialog,
                              onRemove: _removeKeyword,
                            ),
                          ),
                          const SizedBox(height: 24),
                          // 保存按钮
                          FilledButton(
                            onPressed: () async {
                              await _save(includePendingKeyword: true);
                              if (context.mounted) Navigator.of(context).pop();
                            },
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              MaterialLocalizations.of(context).saveButtonLabel,
                            ),
                          ),
                        ],
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
  }
}

class _FilterModeSlider extends StatelessWidget {
  const _FilterModeSlider({
    required this.mode,
    required this.colorScheme,
    required this.theme,
    required this.collapseLabel,
    required this.hideLabel,
    required this.onChanged,
  });

  final CommentFilterMode mode;
  final ColorScheme colorScheme;
  final ThemeData theme;
  final String collapseLabel;
  final String hideLabel;
  final ValueChanged<CommentFilterMode> onChanged;

  bool get _hideSelected => mode == CommentFilterMode.hide;

  @override
  Widget build(BuildContext context) {
    final activeTextColor = colorScheme.onSecondaryContainer;
    final inactiveTextColor = colorScheme.onSurfaceVariant;

    return SizedBox(
      height: 48,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = constraints.maxWidth / 2;
          return Material(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  left: _hideSelected ? itemWidth : 2,
                  top: 2,
                  bottom: 2,
                  width: itemWidth - 2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.shadow.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: _FilterModeSliderItem(
                        icon: Icons.unfold_less_rounded,
                        label: collapseLabel,
                        selected: mode == CommentFilterMode.collapse,
                        activeTextColor: activeTextColor,
                        inactiveTextColor: inactiveTextColor,
                        theme: theme,
                        onTap: () => onChanged(CommentFilterMode.collapse),
                      ),
                    ),
                    Expanded(
                      child: _FilterModeSliderItem(
                        icon: Icons.visibility_off_outlined,
                        label: hideLabel,
                        selected: mode == CommentFilterMode.hide,
                        activeTextColor: activeTextColor,
                        inactiveTextColor: inactiveTextColor,
                        theme: theme,
                        onTap: () => onChanged(CommentFilterMode.hide),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FilterModeSliderItem extends StatelessWidget {
  const _FilterModeSliderItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.activeTextColor,
    required this.inactiveTextColor,
    required this.theme,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color activeTextColor;
  final Color inactiveTextColor;
  final ThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? activeTextColor : inactiveTextColor;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Center(
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          style: theme.textTheme.labelLarge!.copyWith(
            color: color,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 关键词 chip 展示区，超过一定数量时折叠
class _KeywordChipsSection extends StatelessWidget {
  const _KeywordChipsSection({
    required this.keywords,
    required this.expanded,
    required this.colorScheme,
    required this.theme,
    required this.onToggleExpand,
    required this.onEdit,
    required this.onRemove,
  });

  final List<String> keywords;
  final bool expanded;
  final ColorScheme colorScheme;
  final ThemeData theme;
  final VoidCallback onToggleExpand;
  final void Function(String word, int index) onEdit;
  final void Function(String word) onRemove;

  static const _collapseThreshold = 6;

  String _label(String word) {
    if (word.runes.length > 10) {
      return '${String.fromCharCodes(word.runes.take(10))}…';
    }
    return word;
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final showAll = expanded || keywords.length <= _collapseThreshold;
    final visible = showAll
        ? keywords
        : keywords.take(_collapseThreshold).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < visible.length; i++)
                _KeywordChip(
                  label: _label(keywords[i]),
                  colorScheme: colorScheme,
                  theme: theme,
                  onTap: () => onEdit(keywords[i], i),
                  onRemove: () => onRemove(keywords[i]),
                ),
              if (!showAll)
                ActionChip(
                  label: Text('+${keywords.length - _collapseThreshold}'),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  side: BorderSide.none,
                  onPressed: onToggleExpand,
                ),
            ],
          ),
          if (keywords.length > _collapseThreshold) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: onToggleExpand,
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      showAll ? Icons.expand_less : Icons.expand_more,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      showAll
                          ? strings.commentFilterCollapseKeywordList
                          : strings.commentFilterExpandKeywordList(
                              keywords.length,
                            ),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _KeywordChip extends StatelessWidget {
  const _KeywordChip({
    required this.label,
    required this.colorScheme,
    required this.theme,
    required this.onTap,
    required this.onRemove,
  });

  final String label;
  final ColorScheme colorScheme;
  final ThemeData theme;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(width: 2),
            InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(10),
              child: Icon(
                Icons.close,
                size: 14,
                color: colorScheme.onSecondaryContainer.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

class _EditKeywordDialog extends StatelessWidget {
  const _EditKeywordDialog({
    required this.strings,
    required this.editController,
    required this.onSave,
  });

  final AppLocalizations strings;
  final TextEditingController editController;
  final void Function(String newWord) onSave;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Dialog(
      backgroundColor: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              strings.commentFilterEditKeywordTitle,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: editController,
              autofocus: true,
              maxLines: null,
              decoration: InputDecoration(
                filled: true,
                fillColor: colorScheme.surfaceContainer,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: colorScheme.primary,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    MaterialLocalizations.of(context).cancelButtonLabel,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    onSave(editController.text.trim());
                    Navigator.pop(context);
                  },
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    MaterialLocalizations.of(context).saveButtonLabel,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RemoveKeywordDialog extends StatelessWidget {
  const _RemoveKeywordDialog({required this.strings, required this.keyword});

  final AppLocalizations strings;
  final String keyword;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Dialog(
      backgroundColor: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              strings.commentFilterRemoveKeywordTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              strings.commentFilterRemoveKeywordMessage(keyword),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    MaterialLocalizations.of(context).cancelButtonLabel,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(strings.commentFilterRemoveKeywordAction),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
