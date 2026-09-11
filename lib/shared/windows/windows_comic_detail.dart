import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/hazuki_models.dart';

bool get useWindowsComicDetailPanel => Platform.isWindows;
const windowsComicDetailPanelAnimationDuration = Duration(milliseconds: 320);

enum WindowsComicDetailNavigation { open, replace, push, pop }

@immutable
class WindowsComicDetailEntry {
  const WindowsComicDetailEntry({
    required this.comic,
    required this.heroTag,
    required this.revision,
    required this.navigation,
    required this.initialTabIndex,
  });

  final ExploreComic comic;
  final String heroTag;
  final int revision;
  final WindowsComicDetailNavigation navigation;
  final int initialTabIndex;
}

class WindowsComicDetailController extends ChangeNotifier {
  WindowsComicDetailController();

  static final WindowsComicDetailController instance =
      WindowsComicDetailController();

  WindowsComicDetailEntry? _entry;
  final List<WindowsComicDetailEntry> _history = <WindowsComicDetailEntry>[];
  int _revision = 0;
  final Set<int> _temporaryHideTokens = <int>{};
  int _temporaryHideTokenSeed = 0;

  WindowsComicDetailEntry? get entry => _entry;
  bool get isOpen => _entry != null;
  bool get canGoBack => _history.isNotEmpty;
  bool get isTemporarilyHidden => _temporaryHideTokens.isNotEmpty;
  bool get isPanelVisible => _entry != null && !isTemporarilyHidden;

  /// Opens a root detail and clears the previous history.
  void open(ExploreComic comic, String heroTag) {
    final navigation = _entry == null
        ? WindowsComicDetailNavigation.open
        : WindowsComicDetailNavigation.replace;
    _history.clear();
    _show(comic, heroTag, navigation);
  }

  /// Opens a related detail, preserving the current page's restoration state.
  void pushRelated(
    ExploreComic comic,
    String heroTag, {
    int historyTabIndex = 0,
  }) {
    final current = _entry;
    if (current == null) {
      open(comic, heroTag);
      return;
    }
    _history.add(
      WindowsComicDetailEntry(
        comic: current.comic,
        heroTag: current.heroTag,
        revision: current.revision,
        navigation: current.navigation,
        initialTabIndex: historyTabIndex,
      ),
    );
    _show(comic, heroTag, WindowsComicDetailNavigation.push);
  }

  void _show(
    ExploreComic comic,
    String heroTag,
    WindowsComicDetailNavigation navigation,
  ) {
    _temporaryHideTokens.clear();
    _entry = WindowsComicDetailEntry(
      comic: comic,
      heroTag: heroTag,
      revision: ++_revision,
      navigation: navigation,
      initialTabIndex: 0,
    );
    notifyListeners();
  }

  void close() {
    if (_entry == null) {
      return;
    }
    _entry = null;
    _history.clear();
    notifyListeners();
  }

  void goBack() {
    if (_history.isEmpty) {
      close();
      return;
    }

    final previous = _history.removeLast();
    _revision += 1;
    _entry = WindowsComicDetailEntry(
      comic: previous.comic,
      heroTag: previous.heroTag,
      revision: _revision,
      navigation: WindowsComicDetailNavigation.pop,
      initialTabIndex: previous.initialTabIndex,
    );
    notifyListeners();
  }

  Future<void> closeAndWait() async {
    if (_entry == null) {
      return;
    }
    close();
    await Future<void>.delayed(windowsComicDetailPanelAnimationDuration);
  }

  int beginTemporaryHide() {
    if (_entry == null) {
      return 0;
    }
    _temporaryHideTokenSeed += 1;
    _temporaryHideTokens.add(_temporaryHideTokenSeed);
    notifyListeners();
    return _temporaryHideTokenSeed;
  }

  void endTemporaryHide(int token) {
    if (token <= 0 || !_temporaryHideTokens.remove(token)) {
      return;
    }
    notifyListeners();
  }

  Future<T> hideWhile<T>(Future<T> Function() action) async {
    if (_entry == null) {
      return action();
    }

    final token = beginTemporaryHide();
    try {
      return await action();
    } finally {
      endTemporaryHide(token);
    }
  }
}

Future<void> openComicDetail(
  BuildContext context, {
  required ExploreComic comic,
  required String heroTag,
  required Widget Function(ExploreComic comic, String heroTag) pageBuilder,
  bool replaceCurrentRoute = false,
}) async {
  if (useWindowsComicDetailPanel) {
    WindowsComicDetailControllerScope.of(context).open(comic, heroTag);
    return;
  }

  final navigator = Navigator.of(context);
  final route = MaterialPageRoute<void>(
    builder: (_) => pageBuilder(comic, heroTag),
  );

  if (replaceCurrentRoute) {
    await navigator.pushReplacement(route);
    return;
  }

  await navigator.push(route);
}

/// Shares a host session with its descendants without owning its lifetime.
class WindowsComicDetailControllerScope extends InheritedWidget {
  const WindowsComicDetailControllerScope({
    super.key,
    required this.controller,
    required super.child,
  });
  final WindowsComicDetailController controller;
  static WindowsComicDetailController of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<
            WindowsComicDetailControllerScope
          >()
          ?.controller ??
      WindowsComicDetailController.instance;
  @override
  bool updateShouldNotify(WindowsComicDetailControllerScope oldWidget) =>
      controller != oldWidget.controller;
}
