import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/hazuki_models.dart';

AppLocalizations _strings(BuildContext context) => AppLocalizations.of(context)!;

class FavoriteFolderHeader extends StatelessWidget {
  const FavoriteFolderHeader({
    super.key,
    required this.folders,
    required this.selectedFolderId,
    required this.loadingFolders,
    required this.showDeleteAction,
    required this.onDeleteCurrentFolder,
    required this.onSelectFolder,
  });

  final List<FavoriteFolder> folders;
  final String selectedFolderId;
  final bool loadingFolders;
  final bool showDeleteAction;
  final VoidCallback? onDeleteCurrentFolder;
  final ValueChanged<String> onSelectFolder;

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
              if (showDeleteAction)
                Visibility(
                  visible: selectedFolderId != '0',
                  maintainState: true,
                  maintainAnimation: true,
                  maintainSize: true,
                  child: IconButton(
                    tooltip: strings.favoriteDeleteCurrentFolderTooltip,
                    onPressed: selectedFolderId == '0'
                        ? null
                        : onDeleteCurrentFolder,
                    icon: const Icon(Icons.delete_outline),
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
