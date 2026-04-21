import 'package:flutter/material.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';

AppLocalizations _strings(BuildContext context) =>
    AppLocalizations.of(context)!;

class FavoriteFolderHeader extends StatelessWidget {
  const FavoriteFolderHeader({
    super.key,
    required this.folders,
    required this.selectedFolderId,
    required this.loadingFolders,
    required this.showDeleteActionSlot,
    required this.enableDeleteAction,
    required this.onDeleteCurrentFolder,
    required this.onSelectFolder,
    this.onLongPressFolder,
  });

  final List<FavoriteFolder> folders;
  final String selectedFolderId;
  final bool loadingFolders;
  final bool showDeleteActionSlot;
  final bool enableDeleteAction;
  final VoidCallback? onDeleteCurrentFolder;
  final ValueChanged<String> onSelectFolder;
  final ValueChanged<FavoriteFolder>? onLongPressFolder;

  @override
  Widget build(BuildContext context) {
    final strings = _strings(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                strings.favoriteFolderHeader,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Spacer(),
              if (showDeleteActionSlot)
                SizedBox(
                  width: 48,
                  height: 48,
                  child: AnimatedOpacity(
                    opacity: enableDeleteAction ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    child: IgnorePointer(
                      ignoring: !enableDeleteAction,
                      child: IconButton(
                        tooltip: strings.favoriteDeleteCurrentFolderTooltip,
                        onPressed: enableDeleteAction
                            ? onDeleteCurrentFolder
                            : null,
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (loadingFolders)
            const Padding(
              padding: EdgeInsets.only(left: 4, top: 4),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: folders.map((folder) {
                  Widget chip = ChoiceChip(
                    label: Text(
                      folder.isAllFolder
                          ? strings.favoriteAllFolder
                          : folder.name,
                    ),
                    selected: selectedFolderId == folder.id,
                    onSelected: (_) => onSelectFolder(folder.id),
                  );
                  if (onLongPressFolder != null && !folder.isAllFolder) {
                    chip = GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onLongPress: () => onLongPressFolder!(folder),
                      child: chip,
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: chip,
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
