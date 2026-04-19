import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/widgets/widgets.dart';
import 'package:hazuki/pages/favorite/favorite.dart';
import 'package:hazuki/pages/favorite_page.dart';

class HomeShellController extends ChangeNotifier {
  HomeShellController({required int initialTabIndex})
    : _currentIndex = initialTabIndex.clamp(0, 1).toInt();

  int _currentIndex;
  DateTime? _lastBackPressedAt;
  double _discoverSearchMorphProgress = 0;
  FavoriteAppBarActionsState _favoriteAppBarActions =
      const FavoriteAppBarActionsState(
        showSort: false,
        showCreateFolder: false,
        currentSortOrder: 'mr',
        showModeToggle: true,
        currentMode: FavoritePageMode.cloud,
      );

  int get currentIndex => _currentIndex;
  double get discoverSearchMorphProgress => _discoverSearchMorphProgress;
  FavoriteAppBarActionsState get favoriteAppBarActions =>
      _favoriteAppBarActions;

  Future<void> handleDestinationSelected(int index) async {
    if (_currentIndex == index) {
      return;
    }
    await HapticFeedback.lightImpact();
    _currentIndex = index;
    notifyListeners();
  }

  Future<bool> handleWillPop({
    required BuildContext context,
    required GlobalKey<ScaffoldState> scaffoldKey,
  }) async {
    final scaffoldState = scaffoldKey.currentState;
    if (scaffoldState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
      return false;
    }

    final now = DateTime.now();
    final last = _lastBackPressedAt;
    if (last == null || now.difference(last) > const Duration(seconds: 2)) {
      _lastBackPressedAt = now;
      if (context.mounted) {
        await showHazukiPrompt(context, l10n(context).homePressBackAgainToExit);
      }
      return false;
    }
    return true;
  }

  void handleDiscoverSearchMorphProgressChanged(double progress) {
    final next = progress.clamp(0.0, 1.0);
    if ((next - _discoverSearchMorphProgress).abs() < 0.001) {
      return;
    }
    _discoverSearchMorphProgress = next;
    notifyListeners();
  }

  void handleFavoriteAppBarActionsChanged(FavoriteAppBarActionsState state) {
    if (state == _favoriteAppBarActions) {
      return;
    }
    _favoriteAppBarActions = state;
    notifyListeners();
  }

  Future<void> changeFavoriteSortOrder(
    GlobalKey<FavoritePageState> favoritePageKey,
    String order,
  ) async {
    await favoritePageKey.currentState?.changeSortOrder(order);
  }

  Future<void> createFavoriteFolder(
    GlobalKey<FavoritePageState> favoritePageKey,
  ) async {
    await favoritePageKey.currentState?.createFolder();
  }

  Future<void> toggleFavoriteMode(
    GlobalKey<FavoritePageState> favoritePageKey,
  ) async {
    await favoritePageKey.currentState?.toggleMode();
  }
}
