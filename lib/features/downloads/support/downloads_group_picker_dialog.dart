part of 'downloads_group_actions.dart';

class _DownloadGroupPickerDialog extends StatefulWidget {
  const _DownloadGroupPickerDialog({
    required this.groups,
    required this.initiallySelectedGroupIds,
  });

  final List<DownloadGroup> groups;
  final Set<String> initiallySelectedGroupIds;

  @override
  State<_DownloadGroupPickerDialog> createState() =>
      _DownloadGroupPickerDialogState();
}

class _DownloadGroupPickerDialogState
    extends State<_DownloadGroupPickerDialog> {
  late final Set<String> _selected = {...widget.initiallySelectedGroupIds};
  bool _showSelectionRequired = false;

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
      title: Text(strings.downloadsChooseGroup),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: widget.groups.length,
                  itemBuilder: (context, index) {
                    final group = widget.groups[index];
                    final selected = _selected.contains(group.id);
                    return CheckboxListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      value: selected,
                      secondary: const Icon(Icons.folder_outlined),
                      title: Text(
                        group.isDefault
                            ? strings.downloadsDefaultGroup
                            : group.name,
                      ),
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selected.add(group.id);
                          } else {
                            _selected.remove(group.id);
                          }
                          if (_selected.isNotEmpty) {
                            _showSelectionRequired = false;
                          }
                        });
                      },
                    );
                  },
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              child: _showSelectionRequired && _selected.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        strings.downloadsSelectAtLeastOneGroup,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
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
          onPressed: () {
            if (_selected.isEmpty) {
              setState(() => _showSelectionRequired = true);
              return;
            }
            Navigator.pop(context, Set<String>.of(_selected));
          },
          child: Text(strings.downloadsMoveOrAddAction),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurface;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
