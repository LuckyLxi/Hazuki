import 'dart:async';

abstract class FavoritePageActions {
  Future<void> createFolder();
  Future<void> changeSortOrder(String order);
  Future<void> toggleMode();
}

class FavoritePageActionsBinding {
  FavoritePageActions? _current;

  void attach(FavoritePageActions actions) {
    _current = actions;
  }

  void detach(FavoritePageActions actions) {
    if (identical(_current, actions)) {
      _current = null;
    }
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
}
