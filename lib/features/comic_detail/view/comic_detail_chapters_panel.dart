import 'package:hazuki/widgets/chapter_group_picker.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hazuki/shared/text/chinese_conversion_scope.dart';

import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/shared/chapter_title_resolver.dart';

class ComicDetailChaptersPanel extends StatefulWidget {
  const ComicDetailChaptersPanel({
    super.key,
    required this.details,
    required this.onChapterTap,
    required this.onDownloadConfirm,
  });

  final ComicDetailsData details;
  final void Function(String epId, String chapterTitle, int index) onChapterTap;
  final ValueChanged<Set<String>> onDownloadConfirm;

  @override
  State<ComicDetailChaptersPanel> createState() =>
      _ComicDetailChaptersPanelState();
}

class _ComicDetailChaptersPanelState extends State<ComicDetailChaptersPanel> {
  final ScrollController _scrollController = ScrollController();
  final Set<String> _selectedEpIds = <String>{};
  bool _showDownloadSelection = false;
  String? _groupId;

  Map<String, String> get _visibleChapters {
    final groups = widget.details.chapterGroups;
    if (groups.isEmpty) return widget.details.chapters;
    return (groups.where((g) => g.id == _groupId).firstOrNull ?? groups.first)
        .chapters;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _setSelectionMode(bool enabled) {
    setState(() => _showDownloadSelection = enabled);
  }

  void _toggleSelectAllChapters() {
    final chapters = _visibleChapters;
    setState(() {
      if (chapters.keys.every(_selectedEpIds.contains)) {
        _selectedEpIds.removeAll(chapters.keys);
      } else {
        _selectedEpIds.addAll(chapters.keys);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final strings = l10n(context);
    final chapters = _visibleChapters.entries.toList(growable: false);
    final allSelected =
        chapters.isNotEmpty &&
        chapters.every((e) => _selectedEpIds.contains(e.key));
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220);

    return PopScope(
      canPop: !_showDownloadSelection,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _showDownloadSelection) {
          _setSelectionMode(false);
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final screenHeight = MediaQuery.sizeOf(context).height;
          final height = math.min(
            constraints.maxHeight,
            screenHeight < 500 ? screenHeight : screenHeight * 0.74,
          );
          final compact = height < 420;
          return Material(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              height: math.min(height, 760),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.only(
                        top: compact ? 8 : 12,
                        bottom: compact ? 8 : 16,
                      ),
                      child: Container(
                        width: 32,
                        height: 4,
                        decoration: BoxDecoration(
                          color: cs.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          SizedBox.square(
                            dimension: 44,
                            child: AnimatedSwitcher(
                              duration: duration,
                              child: _showDownloadSelection
                                  ? IconButton.filledTonal(
                                      key: const ValueKey('download_back'),
                                      tooltip: MaterialLocalizations.of(
                                        context,
                                      ).backButtonTooltip,
                                      onPressed: () => _setSelectionMode(false),
                                      icon: const Icon(
                                        Icons.arrow_back_rounded,
                                      ),
                                    )
                                  : DecoratedBox(
                                      key: const ValueKey('chapter_icon'),
                                      decoration: BoxDecoration(
                                        color: cs.primaryContainer,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Center(
                                        child: Icon(
                                          Icons.format_list_bulleted_rounded,
                                          color: cs.onPrimaryContainer,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AnimatedSwitcher(
                                  duration: duration,
                                  switchInCurve: Curves.easeOutCubic,
                                  switchOutCurve: Curves.easeInCubic,
                                  layoutBuilder: (child, previousChildren) =>
                                      Stack(
                                        alignment:
                                            AlignmentDirectional.centerStart,
                                        children: [...previousChildren, ?child],
                                      ),
                                  child: Text(
                                    _showDownloadSelection
                                        ? strings.downloadsDownloadChaptersTitle
                                        : strings.comicDetailChapters,
                                    key: ValueKey(_showDownloadSelection),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (!compact) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    convertChineseText(
                                      context,
                                      widget.details.title,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: strings.commonClose,
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        compact ? 4 : 12,
                        12,
                        compact ? 4 : 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _showDownloadSelection
                                  ? '${_selectedEpIds.length} / ${widget.details.chapters.length}'
                                  : strings.comicDetailChapterCount(
                                      '${chapters.length}',
                                    ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: _showDownloadSelection
                                    ? cs.primary
                                    : cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: TextButton.icon(
                                onPressed: chapters.isEmpty
                                    ? null
                                    : _showDownloadSelection
                                    ? _toggleSelectAllChapters
                                    : () => _setSelectionMode(true),
                                icon: Icon(
                                  _showDownloadSelection
                                      ? allSelected
                                            ? Icons.deselect_rounded
                                            : Icons.done_all_rounded
                                      : Icons.download_outlined,
                                  size: 18,
                                ),
                                label: Text(
                                  _showDownloadSelection
                                      ? allSelected
                                            ? strings.commonDeselectAll
                                            : strings.commonSelectAll
                                      : strings.downloadsDownloadAction,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.details.chapterGroups.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: ChapterGroupPicker(
                          details: widget.details,
                          selectedGroupId: _groupId,

                          onSelected: (value) =>
                              setState(() => _groupId = value),
                        ),
                      ),
                    Divider(
                      height: 1,
                      color: cs.outlineVariant.withValues(alpha: 0.5),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, gridConstraints) {
                          final textScale = MediaQuery.textScalerOf(context);
                          final columns =
                              ((gridConstraints.maxWidth - 40) /
                                      (textScale.scale(104) + 10))
                                  .floor()
                                  .clamp(1, 5);
                          return Scrollbar(
                            controller: _scrollController,
                            child: GridView.builder(
                              key: const ValueKey('chapter-grid'),
                              controller: _scrollController,
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                16,
                                20,
                                20,
                              ),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columns,
                                    mainAxisSpacing: 10,
                                    crossAxisSpacing: 10,
                                    mainAxisExtent: 38 + textScale.scale(42),
                                  ),
                              itemCount: chapters.length,
                              itemBuilder: (context, index) {
                                final entry = chapters[index];
                                final title = resolveHazukiChapterTitle(
                                  context,
                                  entry.value,
                                );
                                final selected = _selectedEpIds.contains(
                                  entry.key,
                                );
                                return _ChapterTile(
                                  key: ValueKey(entry.key),
                                  index: index,
                                  title: title,
                                  selectionMode: _showDownloadSelection,
                                  selected: selected,
                                  duration: duration,
                                  onTap: () {
                                    if (!_showDownloadSelection) {
                                      widget.onChapterTap(
                                        entry.key,
                                        title,
                                        widget.details.chapters.keys
                                            .toList()
                                            .indexOf(entry.key),
                                      );
                                      return;
                                    }
                                    setState(() {
                                      if (selected) {
                                        _selectedEpIds.remove(entry.key);
                                      } else {
                                        _selectedEpIds.add(entry.key);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    if (duration == Duration.zero)
                      _buildDownloadFooter(context)
                    else
                      AnimatedSize(
                        duration: duration,
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: _buildDownloadFooter(context),
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

  Widget _buildDownloadFooter(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final strings = l10n(context);
    return _showDownloadSelection
        ? Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(
                top: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
            ),
            child: FilledButton.icon(
              onPressed: _selectedEpIds.isEmpty
                  ? null
                  : () => widget.onDownloadConfirm(
                      Set<String>.from(_selectedEpIds),
                    ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.download_rounded, size: 20),
              label: Text(
                '${strings.downloadsDownloadAction} · ${strings.downloadsSelectionTitle('${_selectedEpIds.length}')}',
                textAlign: TextAlign.center,
              ),
            ),
          )
        : const SizedBox(width: double.infinity);
  }
}

class _ChapterTile extends StatelessWidget {
  const _ChapterTile({
    super.key,
    required this.index,
    required this.title,
    required this.selectionMode,
    required this.selected,
    required this.duration,
    required this.onTap,
  });

  final int index;
  final String title;
  final bool selectionMode;
  final bool selected;
  final Duration duration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final highlighted = selectionMode && selected;
    final radius = BorderRadius.circular(16);
    return Semantics(
      button: true,
      selected: selectionMode ? selected : null,
      label: title,
      excludeSemantics: true,
      onTap: onTap,
      child: Tooltip(
        message: title,
        child: Material(
          color: highlighted ? cs.primaryContainer : cs.surfaceContainerLow,
          animationDuration: duration,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(
              color: highlighted
                  ? cs.primary
                  : cs.outlineVariant.withValues(alpha: 0.55),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${index + 1}'.padLeft(2, '0'),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: highlighted
                                ? cs.primary
                                : cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: duration,
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(
                              scale: animation,
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            ),
                        child: Icon(
                          selectionMode
                              ? selected
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked_rounded
                              : Icons.chevron_right_rounded,
                          key: ValueKey((selectionMode, selected)),
                          size: 18,
                          color: highlighted ? cs.primary : cs.outline,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: highlighted
                              ? cs.onPrimaryContainer
                              : cs.onSurface,
                          fontWeight: FontWeight.w600,
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
  }
}
