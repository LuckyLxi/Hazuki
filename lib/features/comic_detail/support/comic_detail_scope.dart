import 'package:flutter/widgets.dart';

import 'comic_detail_actions_controller.dart';
import 'comic_detail_favorite_controller.dart';
import 'comic_detail_session_controller.dart';
import 'comic_detail_theme_controller.dart';
import 'comic_detail_ui_state_controller.dart';

class ComicDetailScope extends InheritedWidget {
  const ComicDetailScope({
    super.key,
    required this.session,
    required this.uiState,
    required this.theme,
    required this.actions,
    required this.favorite,
    required this.supportsJmExclusiveActions,
    required this.supportsComicLikeAction,
    required super.child,
  });

  final ComicDetailSessionController session;
  final ComicDetailUiStateController uiState;
  final ComicDetailThemeController theme;
  final ComicDetailActionsController actions;
  final ComicDetailFavoriteController favorite;
  final bool supportsJmExclusiveActions;
  final bool supportsComicLikeAction;

  static ComicDetailScope of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<ComicDetailScope>();
    assert(scope != null, 'No ComicDetailScope found in widget tree');
    return scope!;
  }

  @override
  bool updateShouldNotify(ComicDetailScope old) => false;
}
