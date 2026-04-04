import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/hazuki_models.dart';

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
    required this.showCreateLocalFolderButton,
    required this.onDeleteCurrentFolder,
    required this.onSelectFolder,
    this.onCreateLocalFolder,
  });

  final List<FavoriteFolder> folders;
  final String selectedFolderId;
  final bool loadingFolders;
  final bool showDeleteActionSlot;
  final bool enableDeleteAction;
  final bool showCreateLocalFolderButton;
  final VoidCallback? onDeleteCurrentFolder;
  final ValueChanged<String> onSelectFolder;
  final VoidCallback? onCreateLocalFolder;

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
          else if (showCreateLocalFolderButton)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: OutlinedButton.icon(
                onPressed: onCreateLocalFolder,
                icon: const Icon(Icons.create_new_folder_outlined),
                label: Text(strings.favoriteCreateLocalFolderAction),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: folders
                    .map(
                      (folder) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            folder.id == '0'
                                ? strings.favoriteAllFolder
                                : folder.name,
                          ),
                          selected: selectedFolderId == folder.id,
                          onSelected: (_) => onSelectFolder(folder.id),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}
