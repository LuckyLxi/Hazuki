part of 'downloads_group_actions.dart';

class _DownloadsBulkGroupDialog extends StatefulWidget {
  const _DownloadsBulkGroupDialog({
    required this.groups,
    required this.selectedComics,
    required this.initialComicKeysByGroup,
    required this.currentGroupName,
  });

  final List<DownloadGroup> groups;
  final List<DownloadedMangaComic> selectedComics;
  final Map<String, Set<String>> initialComicKeysByGroup;
  final String currentGroupName;

  @override
  State<_DownloadsBulkGroupDialog> createState() =>
      _DownloadsBulkGroupDialogState();
}

class _DownloadsBulkGroupDialogState extends State<_DownloadsBulkGroupDialog> {
  late final DownloadsBulkGroupController _controller;

  DownloadsBulkDialogStage get _stage => _controller.stage;
  Set<String> get _selectedComicKeys => _controller.selectedComicKeys;
  Map<String, Set<String>> get _initialComicKeysByGroup =>
      _controller.initialComicKeysByGroup;
  Map<String, Set<String>> get _draftComicKeysByGroup =>
      _controller.draftComicKeysByGroup;

  @override
  void initState() {
    super.initState();
    _controller = DownloadsBulkGroupController(
      groups: widget.groups,
      selectedComics: widget.selectedComics,
      initialComicKeysByGroup: widget.initialComicKeysByGroup,
    )..addListener(_handleControllerChanged);
  }

  void _handleControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleControllerChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final choosingGroups = _stage == DownloadsBulkDialogStage.groups;
    final confirmingRemoval =
        _stage == DownloadsBulkDialogStage.removeConfirmation;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Center(
        child: AnimatedContainer(
          key: const ValueKey<String>('downloads_bulk_group_dialog'),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          width: choosingGroups ? 420 : (confirmingRemoval ? 340 : 280),
          height: choosingGroups ? 500 : (confirmingRemoval ? 220 : 250),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(confirmingRemoval ? 48 : 28),
            border: Border.all(
              color: confirmingRemoval
                  ? Theme.of(context).colorScheme.error
                  : Colors.transparent,
              width: confirmingRemoval ? 2 : 0,
            ),
          ),
          child: Material(
            // 跟随全局弹窗底色，未配置时回退 M3 默认值。
            color:
                DialogTheme.of(context).backgroundColor ??
                Theme.of(context).colorScheme.surfaceContainerHigh,
            elevation: confirmingRemoval ? 12 : 8,
            borderRadius: BorderRadius.circular(confirmingRemoval ? 48 : 28),
            clipBehavior: Clip.antiAlias,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              layoutBuilder: (currentChild, previousChildren) =>
                  currentChild ?? const SizedBox.shrink(),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.96, end: 1).animate(animation),
                  child: child,
                ),
              ),
              child: switch (_stage) {
                DownloadsBulkDialogStage.actions => _buildActionSelection(
                  context,
                ),
                DownloadsBulkDialogStage.groups => _buildGroupSelection(
                  context,
                ),
                DownloadsBulkDialogStage.removeConfirmation =>
                  _buildRemoveConfirmation(context),
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionSelection(BuildContext context) {
    final strings = l10n(context);
    return Padding(
      key: const ValueKey<String>('downloads_bulk_action_stage'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            strings.downloadsBatchGroupAction,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
          FilledButton.tonalIcon(
            onPressed: _controller.showGroups,
            icon: const Icon(Icons.playlist_add_rounded),
            label: Text(strings.downloadsMoveOrAddAction),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: _controller.showRemoveConfirmation,
            icon: const Icon(Icons.remove_circle_outline),
            label: Text(strings.downloadsRemoveFromCurrentGroup),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildGroupSelection(BuildContext context) {
    final strings = l10n(context);
    return Padding(
      key: const ValueKey<String>('downloads_bulk_group_stage'),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            strings.downloadsChooseGroup,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: widget.groups.length,
              itemBuilder: (context, index) {
                final group = widget.groups[index];
                final initial =
                    _initialComicKeysByGroup[group.id] ?? const <String>{};
                final draft =
                    _draftComicKeysByGroup[group.id] ?? const <String>{};
                final initialAll =
                    initial.length == _selectedComicKeys.length &&
                    _selectedComicKeys.isNotEmpty;
                final value = draft.isEmpty
                    ? false
                    : draft.length == _selectedComicKeys.length
                    ? true
                    : null;
                return Row(
                  children: [
                    Expanded(
                      child: CheckboxListTile(
                        tristate: true,
                        contentPadding: EdgeInsets.zero,
                        value: value,
                        title: Text(
                          group.isDefault
                              ? strings.downloadsDefaultGroup
                              : group.name,
                        ),
                        onChanged: initialAll
                            ? null
                            : (_) => _toggleGroup(group.id),
                      ),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.centerRight,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        switchInCurve: Curves.easeOutBack,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: ScaleTransition(
                              scale: Tween<double>(
                                begin: 0.82,
                                end: 1,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: value == null
                            ? TextButton(
                                key: ValueKey<String>(
                                  'downloads_view_membership_${group.id}',
                                ),
                                onPressed: () =>
                                    _showGroupMembershipDetails(group),
                                child: Text(
                                  strings.downloadsViewGroupMembership,
                                ),
                              )
                            : const SizedBox.shrink(
                                key: ValueKey<String>(
                                  'downloads_view_membership_hidden',
                                ),
                              ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _controller.showActions,
                child: Text(strings.downloadsBack),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () {
                  Navigator.pop(
                    context,
                    DownloadsBulkGroupSelection(
                      action: DownloadsBulkGroupAction.updateMemberships,
                      comicKeysByGroup: _controller.snapshotDraftMemberships(),
                    ),
                  );
                },
                child: Text(strings.commonSave),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRemoveConfirmation(BuildContext context) {
    final strings = l10n(context);
    return Padding(
      key: const ValueKey<String>('downloads_bulk_remove_confirmation_stage'),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            strings.downloadsConfirmRemoveFromGroup(widget.currentGroupName),
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _controller.showActions,
                child: Text(strings.commonCancel),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => Navigator.pop(
                  context,
                  const DownloadsBulkGroupSelection(
                    action: DownloadsBulkGroupAction.removeFromCurrentGroup,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                child: Text(strings.commonConfirm),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _toggleGroup(String groupId) {
    _controller.toggleGroup(groupId);
  }

  Future<void> _showGroupMembershipDetails(DownloadGroup group) async {
    final updated = await showGeneralDialog<Set<String>>(
      context: context,
      barrierDismissible: true,
      barrierLabel: l10n(context).commonClose,
      barrierColor: Colors.black38,
      transitionDuration: const Duration(milliseconds: 300),
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
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(curved),
            child: ScaleTransition(
              key: const ValueKey<String>(
                'downloads_group_membership_details_transition',
              ),
              scale: Tween<double>(begin: 0.9, end: 1).animate(curved),
              child: child,
            ),
          ),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) => Center(
        child: _DownloadsGroupMembershipDetailsDialog(
          group: group,
          comics: widget.selectedComics,
          joinedComicKeys: Set<String>.of(
            _draftComicKeysByGroup[group.id] ?? const {},
          ),
        ),
      ),
    );
    if (updated == null || !mounted) return;
    _controller.updateGroupMembership(group.id, updated);
  }
}
