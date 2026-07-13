part of '../downloads_completed_tab.dart';

class DownloadsCategoryMorphLauncher extends StatefulWidget {
  const DownloadsCategoryMorphLauncher({
    super.key,
    required this.visible,
    required this.landingVersion,
    required this.onPressed,
    required this.label,
    required this.comicCount,
  });

  static const double height = 36;
  static const double cornerRadius = 12;

  final bool visible;
  final int landingVersion;
  final VoidCallback onPressed;
  final String label;
  final int comicCount;

  @override
  State<DownloadsCategoryMorphLauncher> createState() =>
      _DownloadsCategoryMorphLauncherState();
}

class _DownloadsCategoryMorphLauncherState
    extends State<DownloadsCategoryMorphLauncher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _landingController;
  late final Animation<double> _landingOffset;
  late final Animation<double> _landingScale;

  @override
  void initState() {
    super.initState();
    _landingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1,
    );
    final landingCurve = CurvedAnimation(
      parent: _landingController,
      curve: Curves.easeOutCubic,
    );
    _landingOffset = Tween<double>(begin: -3, end: 0).animate(landingCurve);
    _landingScale = Tween<double>(begin: 0.995, end: 1).animate(landingCurve);
  }

  @override
  void didUpdateWidget(covariant DownloadsCategoryMorphLauncher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && widget.landingVersion != oldWidget.landingVersion) {
      _landingController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _landingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final radius = BorderRadius.circular(
      DownloadsCategoryMorphLauncher.cornerRadius,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: AnimatedBuilder(
            animation: _landingController,
            builder: (context, child) {
              return Transform.translate(
                key: const ValueKey<String>(
                  'downloads_category_launcher_landing',
                ),
                offset: Offset(0, _landingOffset.value),
                child: Transform.scale(
                  scale: _landingScale.value,
                  child: child,
                ),
              );
            },
            child: Opacity(
              key: const ValueKey<String>(
                'downloads_category_launcher_opacity',
              ),
              opacity: widget.visible ? 1 : 0,
              child: IgnorePointer(
                ignoring: !widget.visible,
                child: DecoratedBox(
                  key: const ValueKey<String>('downloads_category_launcher'),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: radius,
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withValues(alpha: 0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: radius,
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: widget.onPressed,
                      child: SizedBox(
                        height: DownloadsCategoryMorphLauncher.height,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.folder_copy_outlined,
                              size: 16,
                              color: colorScheme.onPrimaryContainer,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${widget.label} (${widget.comicCount})',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
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
  }
}

class DownloadsCategoryShellDialog extends StatefulWidget {
  const DownloadsCategoryShellDialog({
    super.key,
    required this.animation,
    required this.onDisposed,
    required this.groups,
    required this.selectedGroupId,
    required this.groupComicCounts,
    required this.onSelectGroup,
    required this.onCreateGroup,
    required this.onRenameGroup,
    required this.onReorderGroups,
    required this.onDeleteGroup,
  });

  static const double _dialogHeight = 420;
  static const Duration _groupDeleteAnimationDuration = Duration(
    milliseconds: 260,
  );
  static const Duration _newGroupScrollDuration = Duration(milliseconds: 360);

  final Animation<double> animation;
  final VoidCallback onDisposed;
  final List<DownloadGroup> groups;
  final String selectedGroupId;
  final Map<String, int> groupComicCounts;
  final ValueChanged<String> onSelectGroup;
  final Future<DownloadGroup> Function(String name) onCreateGroup;
  final Future<DownloadGroup> Function(String groupId, String name)
  onRenameGroup;
  final Future<void> Function(List<String> orderedGroupIds) onReorderGroups;
  final Future<void> Function(String groupId) onDeleteGroup;

  @override
  State<DownloadsCategoryShellDialog> createState() =>
      _DownloadsCategoryShellDialogState();
}

class _DownloadsCategoryShellDialogState
    extends State<DownloadsCategoryShellDialog> {
  late List<DownloadGroup> _groups;
  late String _selectedGroupId;
  bool _sorting = false;
  bool _animateGroupTiles = true;
  final Set<String> _deletingGroupIds = <String>{};
  String? _focusedGroupId;
  int _focusVersion = 0;
  String? _highlightGroupId;
  int _highlightVersion = 0;

  @override
  void initState() {
    super.initState();
    _groups = List.of(widget.groups);
    _selectedGroupId = widget.selectedGroupId;
  }

  @override
  void dispose() {
    widget.onDisposed();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final dialogWidth = (constraints.maxWidth - 32).clamp(0.0, 420.0);
        final horizontalPosition = (constraints.maxWidth - dialogWidth) / 2;
        final startTop = mediaQuery.padding.top + kToolbarHeight + 56;
        final endCenterY = constraints.maxHeight / 2;
        final startRect = Rect.fromLTWH(
          horizontalPosition,
          startTop,
          dialogWidth,
          DownloadsCategoryMorphLauncher.height,
        );
        final centeredBarRect = Rect.fromCenter(
          center: Offset(constraints.maxWidth / 2, endCenterY),
          width: dialogWidth,
          height: DownloadsCategoryMorphLauncher.height,
        );
        return AnimatedBuilder(
          animation: widget.animation,
          builder: (context, child) {
            final progress = widget.animation.value;
            final moveProgress = const Interval(
              0,
              0.78,
              curve: Curves.easeOutCubic,
            ).transform(progress);
            final expandProgress = const Interval(
              0.08,
              1,
              curve: Curves.easeOutCubic,
            ).transform(progress);
            final movingRect = Rect.lerp(
              startRect,
              centeredBarRect,
              moveProgress,
            )!;
            final rect = Rect.fromCenter(
              center: movingRect.center,
              width: dialogWidth,
              height:
                  DownloadsCategoryMorphLauncher.height +
                  ((DownloadsCategoryShellDialog._dialogHeight -
                          DownloadsCategoryMorphLauncher.height) *
                      expandProgress),
            );
            final contentOpacity = const Interval(
              0.42,
              0.78,
              curve: Curves.easeOutCubic,
            ).transform(progress);
            final launcherOpacity =
                1 - const Interval(0.12, 0.42).transform(progress);
            final shellColor = Color.lerp(
              colorScheme.primaryContainer,
              colorScheme.surfaceContainerHigh,
              expandProgress,
            )!;
            final borderColor = Color.lerp(
              colorScheme.primary.withValues(alpha: 0.24),
              Colors.transparent,
              expandProgress,
            )!;
            return Stack(
              key: const ValueKey<String>('downloads_category_morph_animation'),
              children: [
                Positioned.fromRect(
                  rect: rect,
                  child: Material(
                    key: const ValueKey<String>('downloads_category_dialog'),
                    color: shellColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        DownloadsCategoryMorphLauncher.cornerRadius +
                            (16 * expandProgress),
                      ),
                      side: BorderSide(color: borderColor),
                    ),
                    clipBehavior: Clip.antiAlias,
                    elevation: 4 + (4 * expandProgress),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Opacity(
                          opacity: launcherOpacity,
                          child: _DownloadsCategoryLauncherContents(
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                        Positioned.fill(
                          child: ClipRect(
                            child: OverflowBox(
                              alignment: Alignment.topCenter,
                              minHeight:
                                  DownloadsCategoryShellDialog._dialogHeight,
                              maxHeight:
                                  DownloadsCategoryShellDialog._dialogHeight,
                              child: Opacity(
                                opacity: contentOpacity,
                                child: _DownloadsCategoryShellContents(
                                  groups: _groups,
                                  selectedGroupId: _selectedGroupId,
                                  groupComicCounts: widget.groupComicCounts,
                                  onSelectGroup: (groupId) {
                                    widget.onSelectGroup(groupId);
                                    Navigator.of(context).pop();
                                  },
                                  onCreateGroup: _createGroup,
                                  onRenameGroup: _renameGroup,
                                  sorting: _sorting,
                                  animateTiles: _animateGroupTiles,
                                  deletingGroupIds: _deletingGroupIds,
                                  focusedGroupId: _focusedGroupId,
                                  focusVersion: _focusVersion,
                                  highlightGroupId: _highlightGroupId,
                                  highlightVersion: _highlightVersion,
                                  onToggleSorting: _toggleSorting,
                                  onReorder: _reorder,
                                  onDeleteGroup: _deleteGroup,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _createGroup() async {
    final name = await _showCreateGroupDialog(context);
    if (name == null || !mounted) return;
    final group = await widget.onCreateGroup(name);
    if (!mounted) return;
    setState(() {
      _animateGroupTiles = false;
      _groups = [..._groups, group];
      _focusedGroupId = group.id;
      _focusVersion++;
      _highlightGroupId = group.id;
      _highlightVersion++;
    });
  }

  Future<void> _renameGroup(DownloadGroup group) async {
    unawaited(HapticFeedback.lightImpact());
    final name = await _showRenameGroupDialog(context, group.name);
    if (name == null || !mounted) return;
    final renamed = await widget.onRenameGroup(group.id, name);
    if (!mounted) return;
    setState(() {
      _groups = [
        for (final item in _groups)
          if (item.id == renamed.id) renamed else item,
      ];
    });
  }

  Future<void> _toggleSorting() async {
    if (!_sorting) {
      setState(() => _sorting = true);
      return;
    }
    await widget.onReorderGroups([
      for (final group in _groups)
        if (!group.isDefault) group.id,
    ]);
    if (!mounted) return;
    setState(() {
      _animateGroupTiles = false;
      _sorting = false;
    });
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      final defaultGroups = [
        for (final group in _groups)
          if (group.isDefault) group,
      ];
      final movableGroups = [
        for (final group in _groups)
          if (!group.isDefault) group,
      ];
      if (oldIndex < 0 || oldIndex >= movableGroups.length) return;
      final group = movableGroups.removeAt(oldIndex);
      final insertIndex = newIndex.clamp(0, movableGroups.length);
      movableGroups.insert(insertIndex, group);
      _groups = [...defaultGroups, ...movableGroups];
    });
  }

  Future<void> _deleteGroup(DownloadGroup group) async {
    final strings = l10n(context);
    final confirmed = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: strings.commonClose,
      barrierColor: Colors.black26,
      transitionDuration: const Duration(milliseconds: 260),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1).animate(curved),
            child: child,
          ),
        );
      },
      pageBuilder: (dialogContext, animation, secondaryAnimation) =>
          AlertDialog(
            title: Text(strings.downloadsDeleteGroupTitle),
            content: Text(strings.downloadsDeleteGroupContent(group.name)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(strings.commonCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(strings.comicDetailDelete),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _animateGroupTiles = false;
      _deletingGroupIds.add(group.id);
    });
    final deleteGroup = widget.onDeleteGroup(group.id);
    await Future.wait<void>([
      deleteGroup,
      Future<void>.delayed(
        DownloadsCategoryShellDialog._groupDeleteAnimationDuration,
      ),
    ]);
    if (!mounted) return;
    setState(() {
      _animateGroupTiles = false;
      _deletingGroupIds.remove(group.id);
      _groups = _groups.where((item) => item.id != group.id).toList();
      if (_selectedGroupId == group.id) {
        _selectedGroupId = DownloadGroupsService.defaultGroupId;
      }
    });
  }
}

class _DownloadsCategoryLauncherContents extends StatelessWidget {
  const _DownloadsCategoryLauncherContents({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.folder_copy_outlined, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          l10n(context).comicDetailCategories,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _DownloadsCategoryShellContents extends StatefulWidget {
  const _DownloadsCategoryShellContents({
    required this.groups,
    required this.selectedGroupId,
    required this.groupComicCounts,
    required this.onSelectGroup,
    required this.onCreateGroup,
    required this.onRenameGroup,
    required this.sorting,
    required this.animateTiles,
    required this.deletingGroupIds,
    required this.focusedGroupId,
    required this.focusVersion,
    required this.highlightGroupId,
    required this.highlightVersion,
    required this.onToggleSorting,
    required this.onReorder,
    required this.onDeleteGroup,
  });

  final List<DownloadGroup> groups;
  final String selectedGroupId;
  final Map<String, int> groupComicCounts;
  final ValueChanged<String> onSelectGroup;
  final VoidCallback onCreateGroup;
  final ValueChanged<DownloadGroup> onRenameGroup;
  final bool sorting;
  final bool animateTiles;
  final Set<String> deletingGroupIds;
  final String? focusedGroupId;
  final int focusVersion;
  final String? highlightGroupId;
  final int highlightVersion;
  final VoidCallback onToggleSorting;
  final ReorderCallback onReorder;
  final ValueChanged<DownloadGroup> onDeleteGroup;

  static const double _groupTileExtent = 56;

  @override
  State<_DownloadsCategoryShellContents> createState() =>
      _DownloadsCategoryShellContentsState();
}

class _DownloadsCategoryShellContentsState
    extends State<_DownloadsCategoryShellContents> {
  late final ScrollController _scrollController = ScrollController();
  bool _positionedSelectedGroup = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _positionSelectedGroup();
    });
  }

  @override
  void didUpdateWidget(covariant _DownloadsCategoryShellContents oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusVersion != oldWidget.focusVersion) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _positionFocusedGroup();
        });
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _positionSelectedGroup() {
    if (_positionedSelectedGroup || !mounted || !_scrollController.hasClients) {
      return;
    }
    final selectedIndex = widget.groups.indexWhere(
      (group) => group.id == widget.selectedGroupId,
    );
    if (selectedIndex < 0) {
      _positionedSelectedGroup = true;
      return;
    }
    final selectedGroup = widget.groups[selectedIndex];
    if (selectedGroup.isDefault) {
      _scrollController.jumpTo(0);
      _positionedSelectedGroup = true;
      return;
    }
    final position = _scrollController.position;
    if (!position.hasContentDimensions) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _positionSelectedGroup();
      });
      return;
    }
    final hasDefaultGroup = widget.groups.any((group) => group.isDefault);
    final nonDefaultIndex = widget.groups
        .where((group) => !group.isDefault)
        .toList(growable: false)
        .indexWhere((group) => group.id == widget.selectedGroupId);
    if (nonDefaultIndex < 0) {
      _positionedSelectedGroup = true;
      return;
    }
    final viewport = position.viewportDimension;
    final target =
        (hasDefaultGroup
            ? _DownloadsCategoryShellContents._groupTileExtent
            : 0) +
        nonDefaultIndex * _DownloadsCategoryShellContents._groupTileExtent -
        (viewport - _DownloadsCategoryShellContents._groupTileExtent) / 2;
    _scrollController.jumpTo(target.clamp(0, position.maxScrollExtent));
    _positionedSelectedGroup = true;
  }

  void _positionFocusedGroup() {
    final groupId = widget.focusedGroupId;
    if (groupId == null || !mounted || !_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (!position.hasContentDimensions) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _positionFocusedGroup();
      });
      return;
    }
    final selectedIndex = widget.groups.indexWhere(
      (group) => group.id == groupId,
    );
    if (selectedIndex < 0) {
      return;
    }
    final viewport = position.viewportDimension;
    final target =
        selectedIndex * _DownloadsCategoryShellContents._groupTileExtent -
        (viewport - _DownloadsCategoryShellContents._groupTileExtent) / 2;
    unawaited(
      _scrollController.animateTo(
        target.clamp(0, position.maxScrollExtent),
        duration: DownloadsCategoryShellDialog._newGroupScrollDuration,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  Widget _buildReorderProxy(
    Widget child,
    int index,
    Animation<double> animation,
  ) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final progress = Curves.easeInOut.transform(animation.value);
        final colorScheme = Theme.of(context).colorScheme;
        return Material(
          color: Colors.transparent,
          elevation: 6 * progress,
          shadowColor: colorScheme.shadow.withValues(alpha: 0.18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        );
      },
      child: child,
    );
  }

  Widget _buildGroupTile(
    BuildContext context, {
    required DownloadGroup group,
    required bool selected,
    int? reorderIndex,
  }) {
    final strings = l10n(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final canReorder = reorderIndex != null && !group.isDefault;
    final highlighted = widget.highlightGroupId == group.id;
    final deleting = widget.deletingGroupIds.contains(group.id);
    final tile = Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: _DownloadGroupHighlight(
        groupId: group.id,
        highlighted: highlighted,
        highlightVersion: widget.highlightVersion,
        baseColor: selected
            ? colorScheme.secondaryContainer
            : colorScheme.surfaceContainerHighest,
        highlightColor: colorScheme.primaryContainer,
        baseBorderColor: selected
            ? colorScheme.primary.withValues(alpha: 0.28)
            : colorScheme.outlineVariant.withValues(alpha: 0.36),
        highlightBorderColor: colorScheme.primary.withValues(alpha: 0.58),
        childBuilder: (context, decoration) {
          return AnimatedContainer(
            key: ValueKey<String>('download_group_background_${group.id}'),
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            decoration: decoration,
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: widget.sorting
                    ? null
                    : () => widget.onSelectGroup(group.id),
                onLongPress: widget.sorting || group.isDefault
                    ? null
                    : () => widget.onRenameGroup(group),
                child: SizedBox(
                  height: 52,
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      Icon(
                        selected
                            ? Icons.folder_open_rounded
                            : Icons.folder_outlined,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          group.isDefault
                              ? '${strings.downloadsDefaultGroup} (${widget.groupComicCounts[group.id] ?? 0})'
                              : '${group.name} (${widget.groupComicCounts[group.id] ?? 0})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(
                        width: group.isDefault ? 12 : 54,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (!group.isDefault && !widget.sorting)
                              IconButton(
                                tooltip: strings.comicDetailDelete,
                                onPressed: () => widget.onDeleteGroup(group),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            if (canReorder && widget.sorting)
                              ReorderableDragStartListener(
                                index: reorderIndex,
                                child: Tooltip(
                                  message: strings.downloadsReorderGroup,
                                  child: const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Icon(Icons.drag_handle_rounded),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
    Widget animatedTile = _DownloadGroupDeleteTransition(
      groupId: group.id,
      deleting: deleting,
      child: tile,
    );
    if (widget.sorting || !widget.animateTiles) {
      return KeyedSubtree(
        key: ValueKey<String>('download_group_${group.id}'),
        child: animatedTile,
      );
    }
    return TweenAnimationBuilder<double>(
      key: ValueKey<String>('download_group_${group.id}'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - value)),
          child: child,
        ),
      ),
      child: animatedTile,
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final theme = Theme.of(context);
    DownloadGroup? defaultGroup;
    for (final group in widget.groups) {
      if (group.isDefault) {
        defaultGroup = group;
        break;
      }
    }
    final sortableGroups = [
      for (final group in widget.groups)
        if (!group.isDefault) group,
    ];
    return SizedBox(
      height: DownloadsCategoryShellDialog._dialogHeight,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    strings.downloadsSwitchGroup,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  layoutBuilder: (currentChild, previousChildren) => Stack(
                    alignment: Alignment.centerRight,
                    children: [...previousChildren, ?currentChild],
                  ),
                  child: widget.sorting
                      ? FilledButton.tonalIcon(
                          key: const ValueKey<String>(
                            'downloads_group_sort_save',
                          ),
                          onPressed: widget.onToggleSorting,
                          icon: const Icon(Icons.save_outlined),
                          label: Text(strings.commonSave),
                        )
                      : IconButton(
                          key: const ValueKey<String>(
                            'downloads_group_sort_start',
                          ),
                          tooltip: strings.downloadsSortGroups,
                          onPressed: widget.onToggleSorting,
                          icon: const Icon(Icons.sort_rounded),
                        ),
                ),
                IconButton(
                  tooltip: strings.downloadsNewGroup,
                  onPressed: widget.sorting ? null : widget.onCreateGroup,
                  icon: const Icon(Icons.create_new_folder_outlined),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ReorderableListView.builder(
                scrollController: _scrollController,
                padding: EdgeInsets.zero,
                header: defaultGroup == null
                    ? null
                    : _buildGroupTile(
                        context,
                        group: defaultGroup,
                        selected: defaultGroup.id == widget.selectedGroupId,
                      ),
                itemCount: sortableGroups.length,
                onReorderItem: widget.onReorder,
                proxyDecorator: _buildReorderProxy,
                buildDefaultDragHandles: false,
                itemBuilder: (context, index) {
                  final group = sortableGroups[index];
                  final selected = group.id == widget.selectedGroupId;
                  return _buildGroupTile(
                    context,
                    group: group,
                    selected: selected,
                    reorderIndex: index,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadGroupDeleteTransition extends StatelessWidget {
  const _DownloadGroupDeleteTransition({
    required this.groupId,
    required this.deleting,
    required this.child,
  });

  final String groupId;
  final bool deleting;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: DownloadsCategoryShellDialog._groupDeleteAnimationDuration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return SizeTransition(
          sizeFactor: animation,
          alignment: Alignment.topCenter,
          child: FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(-0.04, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
        );
      },
      child: deleting
          ? SizedBox.shrink(
              key: ValueKey<String>('download_group_deleted_$groupId'),
            )
          : KeyedSubtree(
              key: ValueKey<String>('download_group_visible_$groupId'),
              child: child,
            ),
    );
  }
}

class _DownloadGroupHighlight extends StatelessWidget {
  const _DownloadGroupHighlight({
    required this.groupId,
    required this.highlighted,
    required this.highlightVersion,
    required this.baseColor,
    required this.highlightColor,
    required this.baseBorderColor,
    required this.highlightBorderColor,
    required this.childBuilder,
  });

  final String groupId;
  final bool highlighted;
  final int highlightVersion;
  final Color baseColor;
  final Color highlightColor;
  final Color baseBorderColor;
  final Color highlightBorderColor;
  final Widget Function(BuildContext context, BoxDecoration decoration)
  childBuilder;

  @override
  Widget build(BuildContext context) {
    BoxDecoration decoration(double pulse) {
      return BoxDecoration(
        color: Color.lerp(baseColor, highlightColor, pulse),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Color.lerp(baseBorderColor, highlightBorderColor, pulse)!,
        ),
      );
    }

    if (!highlighted) {
      return childBuilder(context, decoration(0));
    }
    return TweenAnimationBuilder<double>(
      key: ValueKey<String>(
        'download_group_highlight_${groupId}_$highlightVersion',
      ),
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 980),
      curve: Curves.linear,
      builder: (context, value, child) {
        final pulse = _highlightPulse(value);
        return KeyedSubtree(
          key: ValueKey<String>('download_group_highlight_$groupId'),
          child: childBuilder(context, decoration(pulse)),
        );
      },
    );
  }

  double _highlightPulse(double value) {
    final phase = (value * 4).clamp(0.0, 4.0);
    if (phase <= 1) return phase;
    if (phase <= 2) return 2 - phase;
    if (phase <= 3) return phase - 2;
    return 4 - phase;
  }
}

Future<String?> _showCreateGroupDialog(BuildContext context) async {
  final controller = TextEditingController();
  final strings = l10n(context);
  final value = await showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: strings.commonClose,
    transitionDuration: const Duration(milliseconds: 240),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1).animate(curved),
          child: child,
        ),
      );
    },
    pageBuilder: (dialogContext, animation, secondaryAnimation) =>
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, child) {
            final name = value.text.trim();
            return AlertDialog(
              title: Text(strings.downloadsNewGroup),
              content: TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: strings.downloadsGroupName,
                  errorText: name.isEmpty
                      ? strings.downloadsGroupNameRequired
                      : null,
                ),
                onSubmitted: (_) {
                  if (name.isNotEmpty) Navigator.pop(dialogContext, name);
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(strings.commonCancel),
                ),
                FilledButton(
                  onPressed: name.isEmpty
                      ? null
                      : () => Navigator.pop(dialogContext, name),
                  child: Text(strings.downloadsCreateGroup),
                ),
              ],
            );
          },
        ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 260));
  controller.dispose();
  return value;
}

Future<String?> _showRenameGroupDialog(
  BuildContext context,
  String currentName,
) async {
  final controller = TextEditingController(text: currentName);
  controller.selection = TextSelection(
    baseOffset: 0,
    extentOffset: controller.text.length,
  );
  final strings = l10n(context);
  final value = await showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: strings.commonClose,
    barrierColor: Colors.black26,
    transitionDuration: const Duration(milliseconds: 260),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        ),
        child: ScaleTransition(
          key: const ValueKey<String>('downloads_rename_group_transition'),
          scale: Tween<double>(begin: 0.9, end: 1).animate(curved),
          child: child,
        ),
      );
    },
    pageBuilder: (dialogContext, animation, secondaryAnimation) =>
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, child) {
            final name = value.text.trim();
            return AlertDialog(
              key: const ValueKey<String>('downloads_rename_group_dialog'),
              title: Text(strings.downloadsRenameGroup),
              content: TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: strings.downloadsGroupName,
                  errorText: name.isEmpty
                      ? strings.downloadsGroupNameRequired
                      : null,
                ),
                onSubmitted: (_) {
                  if (name.isNotEmpty) Navigator.pop(dialogContext, name);
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(strings.commonCancel),
                ),
                FilledButton(
                  onPressed: name.isEmpty
                      ? null
                      : () => Navigator.pop(dialogContext, name),
                  child: Text(strings.commonSave),
                ),
              ],
            );
          },
        ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 280));
  controller.dispose();
  return value;
}
