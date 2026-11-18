part of 'downloads_group_actions.dart';

class _DownloadsGroupMembershipDetailsDialog extends StatefulWidget {
  const _DownloadsGroupMembershipDetailsDialog({
    required this.group,
    required this.comics,
    required this.joinedComicKeys,
  });

  final DownloadGroup group;
  final List<DownloadedMangaComic> comics;
  final Set<String> joinedComicKeys;

  @override
  State<_DownloadsGroupMembershipDetailsDialog> createState() =>
      _DownloadsGroupMembershipDetailsDialogState();
}

class _DownloadsGroupMembershipDetailsDialogState
    extends State<_DownloadsGroupMembershipDetailsDialog> {
  static const Duration _coverDismissDuration = Duration(milliseconds: 240);

  late final Set<String> _joinedComicKeys = Set.of(widget.joinedComicKeys);
  final Map<String, bool> _dismissingComicTabs = {};
  bool _showJoined = false;

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final visibleComics = widget.comics
        .where(
          (comic) =>
              _joinedComicKeys.contains(comic.storageKey) == _showJoined ||
              _dismissingComicTabs[comic.storageKey] == _showJoined,
        )
        .toList(growable: false);
    return AlertDialog(
      key: const ValueKey<String>('downloads_group_membership_details_dialog'),
      title: Text(
        widget.group.isDefault
            ? strings.downloadsDefaultGroup
            : widget.group.name,
      ),
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(
          children: [
            _DownloadsMembershipSlider(
              showJoined: _showJoined,
              notJoinedLabel: strings.downloadsNotJoined,
              joinedLabel: strings.downloadsJoined,
              onChanged: (value) => setState(() => _showJoined = value),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: AnimatedSwitcher(
                key: const ValueKey<String>(
                  'downloads_membership_content_switcher',
                ),
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (currentChild, previousChildren) => Stack(
                  alignment: Alignment.topCenter,
                  children: [...previousChildren, ?currentChild],
                ),
                transitionBuilder: (child, animation) {
                  final joined = (child.key as ValueKey<bool>).value;
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: Offset(joined ? 0.08 : -0.08, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey<bool>(_showJoined),
                  child: visibleComics.isEmpty
                      ? Center(child: Text(strings.downloadsNoMatchingComics))
                      : GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 96,
                                childAspectRatio: 0.7,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                          itemCount: visibleComics.length,
                          itemBuilder: (context, index) {
                            final comic = visibleComics[index];
                            return _DownloadsMembershipComicCover(
                              comic: comic,
                              joined: _joinedComicKeys.contains(
                                comic.storageKey,
                              ),
                              dismissing:
                                  _dismissingComicTabs[comic.storageKey] ==
                                  _showJoined,
                              onTap: () => _toggleMembership(comic),
                            );
                          },
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(strings.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, Set.of(_joinedComicKeys)),
          child: Text(strings.commonSave),
        ),
      ],
    );
  }

  void _toggleMembership(DownloadedMangaComic comic) {
    final storageKey = comic.storageKey;
    if (_dismissingComicTabs.containsKey(storageKey)) {
      return;
    }
    final joined = _joinedComicKeys.contains(storageKey);
    setState(() {
      _dismissingComicTabs[storageKey] = joined;
      if (joined) {
        _joinedComicKeys.remove(storageKey);
      } else {
        _joinedComicKeys.add(storageKey);
      }
    });
    Future<void>.delayed(_coverDismissDuration, () {
      if (!mounted) return;
      setState(() => _dismissingComicTabs.remove(storageKey));
    });
  }
}

class _DownloadsMembershipSlider extends StatelessWidget {
  const _DownloadsMembershipSlider({
    required this.showJoined,
    required this.notJoinedLabel,
    required this.joinedLabel,
    required this.onChanged,
  });

  final bool showJoined;
  final String notJoinedLabel;
  final String joinedLabel;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey<String>('downloads_membership_slider'),
      height: 42,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            key: const ValueKey<String>('downloads_membership_slider_thumb'),
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: showJoined
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withValues(alpha: 0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _DownloadsMembershipSliderOption(
                  label: notJoinedLabel,
                  selected: !showJoined,
                  onTap: () => onChanged(false),
                ),
              ),
              Expanded(
                child: _DownloadsMembershipSliderOption(
                  label: joinedLabel,
                  selected: showJoined,
                  onTap: () => onChanged(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DownloadsMembershipSliderOption extends StatelessWidget {
  const _DownloadsMembershipSliderOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            style:
                Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ) ??
                const TextStyle(),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

class _DownloadsMembershipComicCover extends StatelessWidget {
  const _DownloadsMembershipComicCover({
    required this.comic,
    required this.joined,
    required this.dismissing,
    required this.onTap,
  });

  final DownloadedMangaComic comic;
  final bool joined;
  final bool dismissing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      key: ValueKey<String>('downloads_membership_cover_${comic.storageKey}'),
      opacity: dismissing ? 0 : 1,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInCubic,
      child: AnimatedScale(
        scale: dismissing ? 0.78 : 1,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeInBack,
        child: InkWell(
          onTap: dismissing ? null : onTap,
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              DownloadedComicCover(comic: comic, borderRadius: 10),
              Positioned(
                top: 4,
                right: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surface.withValues(alpha: 0.88),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    joined
                        ? Icons.remove_circle_rounded
                        : Icons.add_circle_rounded,
                    color: joined
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
