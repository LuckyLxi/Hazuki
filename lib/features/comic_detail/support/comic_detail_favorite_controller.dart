import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/shared/source_task_owner.dart';
// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/interaction/source_ui_service.dart';
import 'package:hazuki/services/source/interaction/source_ui_scope.dart';
import 'package:hazuki/widgets/hazuki_prompt.dart';

import 'package:hazuki/shared/favorites/favorite_folders_view_model.dart';
import 'package:hazuki/shared/favorites/favorite_folders_button_morph.dart';
import 'package:hazuki/shared/favorites/favorite_selection_applier.dart';
import 'package:hazuki/shared/favorites/favorite_selection_result.dart';

import '../repository/comic_detail_repository.dart';

typedef ComicDetailFavoriteDialogBuilder =
    Widget Function(FavoriteFoldersViewModel viewModel);

class ComicDetailFavoriteController extends ChangeNotifier {
  ComicDetailFavoriteController({
    required SourceTaskControlGateway taskControl,
    required ComicDetailFeatureFacade repository,
  }) : _readTasks = SourceTaskOwner(taskControl),
       _repository = repository;

  final ComicDetailFeatureFacade _repository;
  bool _disposed = false;
  final _sourceUi = SourceUiOwner();
  final SourceTaskOwner _readTasks;

  bool _busy = false;
  String? _busyHeaderActionId;
  bool? _favoriteOverride;
  bool? _cloudFavoriteOverride;
  List<ComicHeaderStat>? _headerStatsOverride;
  List<ComicHeaderBadge>? _headerBadgesOverride;

  bool get isBusy => _busy;

  /// 正在执行的插件顶部动作；执行期间其他插件动作暂不可点。
  String? get busyHeaderActionId => _busyHeaderActionId;
  bool? get favoriteOverride => _favoriteOverride;
  bool? get cloudFavoriteOverride => _cloudFavoriteOverride;

  /// 插件动作返回的新顶部内容，优先于详情数据显示。
  List<ComicHeaderStat>? get headerStatsOverride => _headerStatsOverride;
  List<ComicHeaderBadge>? get headerBadgesOverride => _headerBadgesOverride;

  void applyInitialOverrides({
    required bool favoriteOverride,
    required bool cloudFavoriteOverride,
  }) {
    if (_disposed) return;
    _favoriteOverride = favoriteOverride;
    _cloudFavoriteOverride = cloudFavoriteOverride;
    notifyListeners();
  }

  /// 执行插件声明的顶部动作，返回插件是否要求重新加载详情。
  Future<bool> runHeaderAction(
    BuildContext context,
    ComicDetailsData details,
    ComicHeaderStat stat,
  ) async {
    if (_busyHeaderActionId != null) return false;
    _busyHeaderActionId = stat.actionId;
    notifyListeners();

    try {
      // 插件可能在回调中弹窗，需要页面级交互作用域。
      final result = await _sourceUi.run(
        () => _repository.runComicHeaderAction(
          comicId: details.id,
          actionId: stat.actionId,
          sourceKey: details.sourceKey,
        ),
      );
      if (_disposed) return false;
      _headerStatsOverride = result.headerStats ?? _headerStatsOverride;
      _headerBadgesOverride = result.headerBadges ?? _headerBadgesOverride;
      return result.reload;
    } catch (e) {
      if (_disposed || isSourceUiCancellation(e)) return false;
      unawaited(
        showHazukiPrompt(
          context,
          l10n(context).comicDetailHeaderActionFailed('$e'),
          isError: true,
        ),
      );
      return false;
    } finally {
      if (!_disposed) {
        _busyHeaderActionId = null;
        notifyListeners();
      }
    }
  }

  /// 详情重新加载成功后，以新数据为准。
  void clearHeaderOverrides() {
    if (_disposed ||
        _headerStatsOverride == null && _headerBadgesOverride == null) {
      return;
    }
    _headerStatsOverride = null;
    _headerBadgesOverride = null;
    notifyListeners();
  }

  Future<void> showFoldersDialog(
    BuildContext context,
    ComicDetailsData details,
    ComicDetailFavoriteDialogBuilder dialogBuilder, {
    FavoriteFoldersMorphOrigin? morphOrigin,
    VoidCallback? onDialogClosed,
  }) async {
    if (_busy) return;
    FocusManager.instance.primaryFocus?.unfocus();

    final folders = _repository.favoriteFolders;
    final singleFolderOnly = folders.favoriteSingleFolderForSingleComic;
    _readTasks.restart();
    final viewModel = FavoriteFoldersViewModel(
      readTaskOrigin: _readTasks.origin(),
      repository: folders,
      details: details,
      cloudFavoriteOverride: _cloudFavoriteOverride,
      initialIsFavorite: details.isFavorite,
      singleFolderOnly: singleFolderOnly,
    );

    FavoriteFolderSelectionResult? changed;
    Future<void>? dialogCompleted;
    var buttonRestored = false;
    void restoreButton() {
      if (buttonRestored) return;
      buttonRestored = true;
      onDialogClosed?.call();
    }

    try {
      if (morphOrigin != null) {
        final route = RawDialogRoute<FavoriteFolderSelectionResult>(
          barrierDismissible: true,
          barrierLabel: MaterialLocalizations.of(
            context,
          ).modalBarrierDismissLabel,
          barrierColor: Colors.black.withValues(alpha: 0.46),
          transitionDuration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 560),
          pageBuilder: (context, animation, secondaryAnimation) =>
              FavoriteFoldersMorphScope(
                origin: morphOrigin,
                animation: animation,
                child: dialogBuilder(viewModel),
              ),
          transitionBuilder: (context, animation, secondaryAnimation, child) =>
              child,
        );
        final popped = Navigator.of(context, rootNavigator: true).push(route);
        final animation = route.animation!;
        void handleStatus(AnimationStatus status) {
          if (status == AnimationStatus.dismissed) restoreButton();
        }

        animation.addStatusListener(handleStatus);
        dialogCompleted = route.completed.then((_) {
          animation.removeStatusListener(handleStatus);
        });
        // Save as soon as the result is confirmed. Only cleanup and the
        // caller's button restoration must wait for the overlay to unmount.
        changed = await popped;
      } else {
        changed = await showGeneralDialog<FavoriteFolderSelectionResult>(
          context: context,
          barrierDismissible: true,
          barrierLabel: MaterialLocalizations.of(
            context,
          ).modalBarrierDismissLabel,
          barrierColor: Colors.black.withValues(alpha: 0.46),
          transitionDuration: const Duration(milliseconds: 420),
          pageBuilder: (dialogContext, animation, secondaryAnimation) {
            return dialogBuilder(viewModel);
          },
          transitionBuilder:
              (dialogContext, animation, secondaryAnimation, child) {
                final scale = CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutBack,
                  reverseCurve: Curves.easeInCubic,
                );
                final opacity = CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                  reverseCurve: Curves.easeInCubic,
                );
                final slide =
                    Tween<Offset>(
                      begin: const Offset(0, 0.04),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                        reverseCurve: Curves.easeInCubic,
                      ),
                    );
                return FadeTransition(
                  opacity: opacity,
                  child: SlideTransition(
                    position: slide,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.9, end: 1).animate(scale),
                      child: child,
                    ),
                  ),
                );
              },
        );
      }
      if (changed == null || _disposed) return;

      if (!changed.hasChanges) return;
      final selection = changed;

      _busy = true;
      notifyListeners();

      try {
        final result = await _sourceUi.run(
          () => applyFavoriteFolderSelectionChanges(
            repository: folders,
            details: details,
            selection: selection,
            singleFolderOnly: singleFolderOnly,
          ),
        );
        if (_disposed) return;
        _favoriteOverride = result.hasSelection;
        _cloudFavoriteOverride = result.hasCloudSelection;

        unawaited(
          showHazukiPrompt(
            context,
            l10n(context).comicDetailFavoriteSettingsUpdated,
          ),
        );
      } catch (e) {
        if (_disposed || isSourceUiCancellation(e)) return;
        unawaited(
          showHazukiPrompt(
            context,
            l10n(context).comicDetailFavoriteSettingsUpdateFailed('$e'),
            isError: true,
          ),
        );
      } finally {
        if (!_disposed) {
          _busy = false;
          notifyListeners();
        }
      }
    } finally {
      if (dialogCompleted != null) await dialogCompleted;
      viewModel.dispose();
      restoreButton();
    }
  }

  @override
  void dispose() {
    _readTasks.dispose();
    _sourceUi.dispose();
    _disposed = true;
    super.dispose();
  }
}
