import 'package:flutter/widgets.dart';

import 'comic_detail_actions_controller.dart';
import 'comic_detail_favorite_controller.dart';
import 'comic_detail_session_controller.dart';
import 'comic_detail_theme_controller.dart';

class ComicDetailScope extends InheritedWidget {
  const ComicDetailScope({
    super.key,
    required this.session,
    required this.theme,
    required this.actions,
    required this.favorite,
    required super.child,
  });

  final ComicDetailSessionController session;
  final ComicDetailThemeController theme;
  final ComicDetailActionsController actions;
  final ComicDetailFavoriteController favorite;

  static ComicDetailScope of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ComicDetailScope>();
    assert(scope != null, 'No ComicDetailScope found in widget tree');
    return scope!;
  }

  @override
  bool updateShouldNotify(ComicDetailScope old) => false;
}
