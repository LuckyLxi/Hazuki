import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../../models/hazuki_models.dart';
import '../../services/hazuki_source_service.dart';
import '../../services/local_favorites_service.dart';
import '../../widgets/widgets.dart';
import 'comic_detail_morph_loader.dart';

enum _FavoriteDialogPhase { loading, result }

class FavoriteFoldersMorphDialog extends StatefulWidget {
  const FavoriteFoldersMorphDialog({
    super.key,
    required this.details,
    required this.singleFolderOnly,
    required this.favoriteOverride,
    required this.initialIsFavorite,
  });

  final ComicDetailsData details;
  final bool singleFolderOnly;
  final bool? favoriteOverride;
  final bool initialIsFavorite;

  @override
  State<FavoriteFoldersMorphDialog> createState() =>
      _FavoriteFoldersMorphDialogState();
}

class _FavoriteFoldersMorphDialogState
    extends State<FavoriteFoldersMorphDialog> {
  final HazukiSourceService _service = HazukiSourceService.instance;
  final LocalFavoritesService _localService = LocalFavoritesService.instance;

  _FavoriteDialogPhase _phase = _FavoriteDialogPhase.loading;
  bool _busy = false;
  String? _loadError;
  List<FavoriteFolder> _cloudFolders = <FavoriteFolder>[];
  List<FavoriteFolder> _localFolders = <FavoriteFolder>[];
  Set<String> _selected = <String>{};
  Set<String> _initialFavorited = <String>{};

  bool get _showExpandedDialog => _phase == _FavoriteDialogPhase.result;

  bool get _canLoadCloudFolders =>
      _service.isLogged && _service.supportFavoriteFolderLoad;

  bool get _canCreateCloudFolder =>
      _service.isLogged && _service.supportFavoriteFolderAdd;

  bool get _canDeleteCloudFolder =>
      _service.isLogged && _service.supportFavoriteFolderDelete;

  bool get _canUseCloudDefaultFavoriteFallback =>
      _service.isLogged && _service.supportFavoriteToggle;

  Future<T?> _showAnimatedDialog<T>({required WidgetBuilder builder}) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return builder(dialogContext);
      },
      transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final scale = Tween<double>(begin: 0.92, end: 1).animate(
          CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutBack,
            reverseCurve: Curves.easeInCubic,
          ),
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(scale: scale, child: child),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadFolders(initialLoad: true));
  }

  Future<void> _loadFolders({
    bool initialLoad = false,
    bool preserveSelection = false,
  }) async {
    if (!mounted) {
      return;
    }

    final previousSelected = Set<String>.from(_selected);
    final previousInitialFavorited = Set<String>.from(_initialFavorited);

    setState(() {
      if (initialLoad) {
        _phase = _FavoriteDialogPhase.loading;
      } else {
        _busy = true;
      }
      _loadError = null;
    });

    try {
      final localResult = await _localService.loadFavoriteFolders(
        comicId: widget.details.id,
      );
      final cloudResult = _canLoadCloudFolders
          ? await _service.loadFavoriteFolders(comicId: widget.details.id)
          : const FavoriteFoldersResult.success(
              folders: <FavoriteFolder>[],
              favoritedFolderIds: <String>{},
            );
      if (!mounted) {
        return;
      }

      final cloudFolders = List<FavoriteFolder>.from(cloudResult.folders);
      if (cloudFolders.isEmpty && _canUseCloudDefaultFavoriteFallback) {
        cloudFolders.add(
          const FavoriteFolder(
            id: '0',
            name: '__favorite_all__',
            source: FavoriteFolderSource.cloud,
          ),
        );
      }
      final localFolders = List<FavoriteFolder>.from(localResult.folders);
      final nextInitialFavorited = <String>{
        ..._toStorageKeys(
          favoritedFolderIds: cloudResult.favoritedFolderIds,
          source: FavoriteFolderSource.cloud,
        ),
        ..._toStorageKeys(
          favoritedFolderIds: localResult.favoritedFolderIds,
          source: FavoriteFolderSource.local,
        ),
      };

      if (nextInitialFavorited.isEmpty &&
          widget.singleFolderOnly &&
          (widget.favoriteOverride ?? widget.initialIsFavorite) &&
          _canUseCloudDefaultFavoriteFallback &&
          cloudFolders.isNotEmpty) {
        nextInitialFavorited.add(
          const FavoriteFolderHandle(
            source: FavoriteFolderSource.cloud,
            id: '0',
          ).storageKey,
        );
      }

      final availableKeys = <String>{
        ...cloudFolders.map((folder) => folder.storageKey),
        ...localFolders.map((folder) => folder.storageKey),
      };

      setState(() {
        _phase = _FavoriteDialogPhase.result;
        _busy = false;
        _cloudFolders = cloudFolders;
        _localFolders = localFolders;

        if (preserveSelection) {
          _initialFavorited = previousInitialFavorited.intersection(
            availableKeys,
          );
          _selected = previousSelected.intersection(availableKeys);
        } else {
          _initialFavorited = nextInitialFavorited;
          _selected = Set<String>.from(nextInitialFavorited);
        }

        if (cloudResult.errorMessage != null &&
            _cloudFolders.isEmpty &&
            _localFolders.length <= 1) {
          _loadError = cloudResult.errorMessage;
        } else {
          _loadError = null;
        }
      });
      if (initialLoad) {
        unawaited(HapticFeedback.selectionClick());
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _phase = _FavoriteDialogPhase.result;
        _busy = false;
        _loadError = e.toString();
      });
      if (initialLoad) {
        unawaited(HapticFeedback.selectionClick());
      }
    }
  }

  Set<String> _toStorageKeys({
    required Set<String> favoritedFolderIds,
    required FavoriteFolderSource source,
  }) {
    return favoritedFolderIds
        .map((id) => FavoriteFolderHandle(source: source, id: id).storageKey)
        .toSet();
  }

  Future<FavoriteFolderSource?> _pickCreateFolderTarget() async {
    final availableTargets = <FavoriteFolderSource>[
      if (_canCreateCloudFolder) FavoriteFolderSource.cloud,
      FavoriteFolderSource.local,
    ];
    if (availableTargets.isEmpty) {
      return null;
    }
    if (availableTargets.length == 1) {
      return availableTargets.first;
    }

    return _showAnimatedDialog<FavoriteFolderSource>(
      builder: (dialogContext) {
        final strings = AppLocalizations.of(dialogContext)!;
        return AlertDialog(
          title: Text(strings.favoriteCreateFolderTargetTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.cloud_outlined),
                title: Text(strings.favoriteCreateFolderTargetCloud),
                onTap: () =>
                    Navigator.of(dialogContext).pop(FavoriteFolderSource.cloud),
              ),
              ListTile(
                leading: const Icon(Icons.folder_copy_outlined),
                title: Text(strings.favoriteCreateFolderTargetLocal),
                onTap: () =>
                    Navigator.of(dialogContext).pop(FavoriteFolderSource.local),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<String?> _promptFolderName(FavoriteFolderSource target) {
    final strings = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    return _showAnimatedDialog<String>(
      builder: (dialogContext) {
        String? errorText;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(
                '${strings.favoriteCreateFolderTitle} - '
                '${_folderSourceLabel(dialogContext, target)}',
              ),
              content: TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: strings.comicDetailFavoriteFolderNameHint,
                  border: const OutlineInputBorder(),
                  errorText: errorText,
                ),
                onChanged: (_) {
                  if (errorText != null) {
                    setDialogState(() => errorText = null);
                  }
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(strings.commonCancel),
                ),
                FilledButton(
                  onPressed: () {
                    final text = controller.text.trim();
                    if (text.isEmpty) {
                      setDialogState(
                        () => errorText =
                            strings.comicDetailFavoriteFolderNameRequired,
                      );
                      return;
                    }
                    Navigator.pop(dialogContext, text);
                  },
                  child: Text(strings.commonConfirm),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(controller.dispose);
  }

  Future<void> _addFolder() async {
    final target = await _pickCreateFolderTarget();
    if (target == null || !mounted) {
      return;
    }

    final name = await _promptFolderName(target);
    if (name == null || name.isEmpty || !mounted) {
      return;
    }

    setState(() {
      _busy = true;
    });
    try {
      if (target == FavoriteFolderSource.local) {
        await _localService.addFavoriteFolder(name);
      } else {
        await _service.addFavoriteFolder(name);
      }
      if (!mounted) {
        return;
      }
      await _loadFolders(preserveSelection: true);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
      });
      unawaited(
        showHazukiPrompt(
          context,
          AppLocalizations.of(
            context,
          )!.comicDetailCreateFavoriteFolderFailed('$e'),
          isError: true,
        ),
      );
    }
  }

  Future<void> _deleteFolder(FavoriteFolder folder) async {
    final strings = AppLocalizations.of(context)!;
    final ok = await _showAnimatedDialog<bool>(
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(strings.comicDetailDeleteFavoriteFolder),
          content: Text(strings.comicDetailDeleteFavoriteFolderContent),
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
        );
      },
    );
    if (ok != true || !mounted) {
      return;
    }

    setState(() {
      _busy = true;
    });
    try {
      if (folder.source == FavoriteFolderSource.local) {
        await _localService.deleteFavoriteFolder(folder.id);
      } else {
        await _service.deleteFavoriteFolder(folder.id);
      }
      if (!mounted) {
        return;
      }
      await _loadFolders(preserveSelection: true);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
      });
      unawaited(
        showHazukiPrompt(
          context,
          strings.comicDetailDeleteFavoriteFolderFailed('$e'),
          isError: true,
        ),
      );
    }
  }

  void _toggleFolder(FavoriteFolder folder, {bool? value}) {
    if (_busy) {
      return;
    }
    final folderKey = folder.storageKey;
    final checked = _selected.contains(folderKey);
    final enable = value ?? !checked;
    setState(() {
      final nextSelected = Set<String>.from(_selected);
      if (enable) {
        if (folder.source == FavoriteFolderSource.cloud &&
            widget.singleFolderOnly) {
          nextSelected.removeWhere((storageKey) {
            final handle = favoriteFolderHandleFromStorageKey(storageKey);
            return handle?.source == FavoriteFolderSource.cloud;
          });
        }
        nextSelected.add(folderKey);
      } else {
        nextSelected.remove(folderKey);
      }
      _selected = nextSelected;
    });
  }

  void _handleSave() {
    if (_busy || _loadError != null) {
      return;
    }
    if (_selected.isEmpty && _initialFavorited.isEmpty) {
      unawaited(
        showHazukiPrompt(
          context,
          AppLocalizations.of(context)!.comicDetailSelectAtLeastOneFolder,
          isError: true,
        ),
      );
      return;
    }
    Navigator.of(context).pop(<String, Set<String>>{
      'selected': Set<String>.from(_selected),
      'initial': Set<String>.from(_initialFavorited),
    });
  }

  String _folderSourceLabel(BuildContext context, FavoriteFolderSource source) {
    final strings = AppLocalizations.of(context)!;
    return source == FavoriteFolderSource.local
        ? strings.favoriteModeLocal
        : strings.favoriteModeCloud;
  }

  Widget _buildLoadingContent(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return SizedBox(
      key: const ValueKey('favorite_dialog_loading'),
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          const ShapeMorphingLoader(size: 90),
          const SizedBox(height: 18),
          Text(
            AppLocalizations.of(context)!.commonLoading,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.comicDetailManageFavorites,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildStateCard({
    required Widget icon,
    required String message,
    required Color backgroundColor,
  }) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildFolderTile(
    BuildContext context,
    FavoriteFolder folder, {
    required bool allowDelete,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final checked = _selected.contains(folder.storageKey);
    final title = folder.isAllFolder
        ? AppLocalizations.of(context)!.favoriteAllFolder
        : folder.name;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: checked
            ? cs.primaryContainer.withValues(alpha: 0.88)
            : cs.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: checked
              ? cs.primary.withValues(alpha: 0.34)
              : cs.outlineVariant.withValues(alpha: 0.28),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 2,
          ),
          leading: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: checked ? cs.primary : cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              checked ? Icons.check_rounded : Icons.add_rounded,
              size: 18,
              color: checked ? cs.onPrimary : cs.onSurfaceVariant,
            ),
          ),
          title: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          trailing: !folder.isAllFolder && allowDelete
              ? IconButton(
                  tooltip: AppLocalizations.of(
                    context,
                  )!.comicDetailDeleteFavoriteFolderTooltip,
                  onPressed: _busy ? null : () => _deleteFolder(folder),
                  icon: const Icon(Icons.delete_outline_rounded),
                )
              : null,
          onTap: () => _toggleFolder(folder),
        ),
      ),
    );
  }

  Widget _buildSectionContent(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<FavoriteFolder> folders,
    required bool allowDelete,
  }) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: cs.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            for (var i = 0; i < folders.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _buildFolderTile(context, folders[i], allowDelete: allowDelete),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDialogBody(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasFolders = _cloudFolders.isNotEmpty || _localFolders.isNotEmpty;
    if (_loadError != null && !hasFolders) {
      return _buildStateCard(
        icon: Icon(Icons.error_outline_rounded, size: 28, color: cs.error),
        message: AppLocalizations.of(
          context,
        )!.comicDetailFavoriteFoldersLoadFailed('$_loadError'),
        backgroundColor: cs.errorContainer.withValues(alpha: 0.32),
      );
    }

    if (!hasFolders) {
      return _buildStateCard(
        icon: Icon(
          Icons.folder_off_outlined,
          size: 28,
          color: cs.onSurfaceVariant,
        ),
        message: AppLocalizations.of(context)!.comicDetailNoFavoriteFolders,
        backgroundColor: cs.surfaceContainerLow.withValues(alpha: 0.72),
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: math.min(MediaQuery.sizeOf(context).height * 0.36, 320),
      ),
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        children: [
          if (_cloudFolders.isNotEmpty)
            _buildSectionContent(
              context,
              title: AppLocalizations.of(context)!.favoriteFolderGroupCloud,
              icon: Icons.cloud_outlined,
              folders: _cloudFolders,
              allowDelete: _canDeleteCloudFolder,
            ),
          if (_cloudFolders.isNotEmpty && _localFolders.isNotEmpty)
            const SizedBox(height: 12),
          if (_localFolders.isNotEmpty)
            _buildSectionContent(
              context,
              title: AppLocalizations.of(context)!.favoriteFolderGroupLocal,
              icon: Icons.folder_copy_outlined,
              folders: _localFolders,
              allowDelete: true,
            ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return SizedBox(
      key: ValueKey<String>(
        _loadError == null ? 'favorite_dialog_loaded' : 'favorite_dialog_error',
      ),
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.comicDetailManageFavorites,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_loadError == null)
                IconButton(
                  tooltip: AppLocalizations.of(
                    context,
                  )!.comicDetailCreateFavoriteFolderTooltip,
                  onPressed: _busy ? null : _addFolder,
                  icon: const Icon(Icons.create_new_folder_outlined),
                ),
              IconButton(
                tooltip: AppLocalizations.of(context)!.commonClose,
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          Text(
            widget.singleFolderOnly
                ? AppLocalizations.of(context)!.comicDetailSingleFolderHint
                : AppLocalizations.of(context)!.comicDetailMultipleFoldersHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          _buildDialogBody(context),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  child: Text(AppLocalizations.of(context)!.commonClose),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _busy
                      ? null
                      : _loadError != null
                      ? () => unawaited(_loadFolders())
                      : _handleSave,
                  child: Text(
                    _loadError != null
                        ? AppLocalizations.of(context)!.commonRetry
                        : AppLocalizations.of(context)!.commonSave,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBusyOverlay(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Positioned.fill(
      child: IgnorePointer(
        child: ColoredBox(
          color: cs.surface.withValues(alpha: 0.72),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ShapeMorphingLoader(size: 54),
                const SizedBox(height: 12),
                Text(
                  AppLocalizations.of(context)!.commonLoading,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final size = MediaQuery.sizeOf(context);
    final expanded = _showExpandedDialog;
    final dialogWidth = expanded
        ? math.min(size.width * 0.9, 460.0)
        : math.min(size.width * 0.78, 320.0);

    return SafeArea(
      child: Material(
        type: MaterialType.transparency,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 460),
              curve: Curves.easeInOutCubicEmphasized,
              width: dialogWidth,
              constraints: BoxConstraints(
                minHeight: expanded ? 0 : 196,
                maxHeight: expanded ? math.min(size.height * 0.78, 520) : 220,
              ),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(expanded ? 32 : 28),
                border: Border.all(
                  color: cs.outlineVariant.withValues(
                    alpha: expanded ? 0.24 : 0.16,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: expanded ? 30 : 22,
                    spreadRadius: -6,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      expanded ? 20 : 24,
                      24,
                      expanded ? 20 : 24,
                    ),
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 460),
                      curve: Curves.easeInOutCubicEmphasized,
                      alignment: Alignment.center,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          final slide = Tween<Offset>(
                            begin: const Offset(0, 0.08),
                            end: Offset.zero,
                          ).animate(animation);
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: slide,
                              child: child,
                            ),
                          );
                        },
                        child: expanded
                            ? _buildExpandedContent(context)
                            : _buildLoadingContent(context),
                      ),
                    ),
                  ),
                  if (_busy && expanded) _buildBusyOverlay(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
