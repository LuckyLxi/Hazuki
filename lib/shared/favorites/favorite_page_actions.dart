import 'dart:async';

import 'package:flutter/foundation.dart';

abstract class FavoritePageActions {
  bool get backToTopVisible;

  Future<void> createFolder();
  Future<void> changeSortOrder(String order);
  Future<void> toggleMode();
  Future<void> scrollToTop();
}

class FavoritePageActionsBinding extends ChangeNotifier {
  FavoritePageActions? _current;
  bool _backToTopVisible = false;

  bool get backToTopVisible => _backToTopVisible;

  void attach(FavoritePageActions actions) {
    _current = actions;
    _setBackToTopVisible(actions.backToTopVisible);
  }

  void detach(FavoritePageActions actions) {
    if (identical(_current, actions)) {
      _current = null;
      _setBackToTopVisible(false);
    }
  }

  void updateBackToTopVisibility(
    FavoritePageActions actions, {
    required bool visible,
  }) {
    if (!identical(_current, actions)) {
      return;
    }
    _setBackToTopVisible(visible);
  }

  Future<void> createFolder() async {
    await _current?.createFolder();
  }

  Future<void> changeSortOrder(String order) async {
    await _current?.changeSortOrder(order);
  }

  Future<void> toggleMode() async {
    await _current?.toggleMode();
  }

  Future<void> scrollToTop() async {
    await _current?.scrollToTop();
  }

  void _setBackToTopVisible(bool visible) {
    if (_backToTopVisible == visible) {
      return;
    }
    _backToTopVisible = visible;
    notifyListeners();
  }
}
