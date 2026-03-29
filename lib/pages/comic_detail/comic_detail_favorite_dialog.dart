import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/hazuki_models.dart';
import '../../services/hazuki_source_service.dart';
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

  _FavoriteDialogPhase _phase = _FavoriteDialogPhase.loading;
  bool _busy = false;
  String? _loadError;
  List<FavoriteFolder> _folders = <FavoriteFolder>[];
  Set<String> _selected = <String>{};
  Set<String> _initialFavorited = <String>{};

  bool get _showExpandedDialog => _phase == _FavoriteDialogPhase.result;

  @override
  void initState() {
    super.initState();
    unawaited(_loadFolders(initialLoad: true));
  }

  Future<void> _loadFolders({bool initialLoad = false}) async {
    if (!mounted) {
      return;
    }
    setState(() {
      if (initialLoad) {
        _phase = _FavoriteDialogPhase.loading;
      } else {
        _busy = true;
      }
      _loadError = null;
    });

    try {
      final result = await _service.loadFavoriteFolders(
        comicId: widget.details.id,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _phase = _FavoriteDialogPhase.result;
        _busy = false;
        if (result.errorMessage != null) {
          _loadError = result.errorMessage;
          return;
        }
        final favorited = Set<String>.from(result.favoritedFolderIds);
        if (favorited.isEmpty &&
            widget.singleFolderOnly &&
            (widget.favoriteOverride ?? widget.initialIsFavorite)) {
          favorited.add('0');
        }
        _loadError = null;
        _folders = List<FavoriteFolder>.from(result.folders);
        _initialFavorited = favorited;
        _selected = Set<String>.from(favorited);
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _phase = _FavoriteDialogPhase.result;
        _busy = false;
        _loadError = e.toString();
      });
    }
  }

  Future<void> _addFolder() async {
    final strings = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        String? errorText;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(strings.comicDetailCreateFavoriteFolder),
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
    );
    controller.dispose();
    if (name == null || name.isEmpty || !mounted) {
      return;
    }

    setState(() {
      _busy = true;
    });
    try {
      await _service.addFavoriteFolder(name);
      final refreshed = await _service.loadFavoriteFolders(
        comicId: widget.details.id,
      );
      if (refreshed.errorMessage != null) {
        throw Exception(refreshed.errorMessage);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _folders = List<FavoriteFolder>.from(refreshed.folders);
        _loadError = null;
        _busy = false;
      });
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
          strings.comicDetailCreateFavoriteFolderFailed('$e'),
          isError: true,
        ),
      );
    }
  }

  Future<void> _deleteFolder(String folderId) async {
    final strings = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
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
      await _service.deleteFavoriteFolder(folderId);
      if (!mounted) {
        return;
      }
      setState(() {
        final deletedASelectedFolder =
            _selected.contains(folderId) ||
            _initialFavorited.contains(folderId);
        final nextSelected = Set<String>.from(_selected)..remove(folderId);
        final nextInitialFavorited = Set<String>.from(_initialFavorited)
          ..remove(folderId);
        if (deletedASelectedFolder &&
            widget.singleFolderOnly &&
            nextSelected.isEmpty) {
          nextSelected.add('0');
        }
        if (deletedASelectedFolder &&
            widget.singleFolderOnly &&
            nextInitialFavorited.isEmpty) {
          nextInitialFavorited.add('0');
        }
        _folders = _folders.where((e) => e.id != folderId).toList();
        _selected = nextSelected;
        _initialFavorited = nextInitialFavorited;
        _loadError = null;
        _busy = false;
      });
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

  void _toggleFolder(String folderId, {bool? value}) {
    if (_busy) {
      return;
    }
    final checked = _selected.contains(folderId);
    final enable = value ?? !checked;
    setState(() {
      if (enable) {
        if (widget.singleFolderOnly) {
          _selected = <String>{folderId};
        } else {
          _selected = Set<String>.from(_selected)..add(folderId);
        }
      } else {
        _selected = Set<String>.from(_selected)..remove(folderId);
      }
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

  Widget _buildFolderTile(BuildContext context, FavoriteFolder folder) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final checked = _selected.contains(folder.id);
    final title = folder.id == '0'
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
          trailing: folder.id != '0' && _service.supportFavoriteFolderDelete
              ? IconButton(
                  tooltip: AppLocalizations.of(
                    context,
                  )!.comicDetailDeleteFavoriteFolderTooltip,
                  onPressed: _busy ? null : () => _deleteFolder(folder.id),
                  icon: const Icon(Icons.delete_outline_rounded),
                )
              : null,
          onTap: () => _toggleFolder(folder.id),
        ),
      ),
    );
  }

  Widget _buildDialogBody(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_loadError != null) {
      return _buildStateCard(
        icon: Icon(Icons.error_outline_rounded, size: 28, color: cs.error),
        message: AppLocalizations.of(
          context,
        )!.comicDetailFavoriteFoldersLoadFailed('$_loadError'),
        backgroundColor: cs.errorContainer.withValues(alpha: 0.32),
      );
    }

    if (_folders.isEmpty) {
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

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.18)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: math.min(MediaQuery.sizeOf(context).height * 0.28, 240),
        ),
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.all(10),
          itemCount: _folders.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) =>
              _buildFolderTile(context, _folders[index]),
        ),
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
              if (_service.supportFavoriteFolderAdd && _loadError == null)
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
        ? math.min(size.width * 0.9, 440.0)
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
                maxHeight: expanded ? math.min(size.height * 0.68, 420) : 220,
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
