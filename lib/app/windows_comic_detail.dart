import 'dart:io';

import 'package:flutter/material.dart';

import '../models/hazuki_models.dart';

bool get useWindowsComicDetailPanel => Platform.isWindows;
const windowsComicDetailPanelAnimationDuration = Duration(milliseconds: 320);

@immutable
class WindowsComicDetailEntry {
  const WindowsComicDetailEntry({
    required this.comic,
    required this.heroTag,
    required this.revision,
  });

  final ExploreComic comic;
  final String heroTag;
  final int revision;
}

class WindowsComicDetailController extends ChangeNotifier {
  WindowsComicDetailController._();

  static final WindowsComicDetailController instance =
      WindowsComicDetailController._();

  WindowsComicDetailEntry? _entry;
  int _revision = 0;
  int _temporaryHideDepth = 0;
  int? _pendingPanelRevealRevision;

  WindowsComicDetailEntry? get entry => _entry;
  bool get isOpen => _entry != null;
  bool get isTemporarilyHidden => _temporaryHideDepth > 0;
  bool get isPanelVisible => _entry != null && !isTemporarilyHidden;

  bool shouldAnimatePanelReveal(WindowsComicDetailEntry entry) {
    return _pendingPanelRevealRevision == entry.revision;
  }

  void markPanelRevealHandled(WindowsComicDetailEntry entry) {
    if (_pendingPanelRevealRevision != entry.revision) {
      return;
    }
    _pendingPanelRevealRevision = null;
  }

  void open(ExploreComic comic, String heroTag) {
    final shouldAnimatePanelReveal = _entry == null;
    _revision += 1;
    _entry = WindowsComicDetailEntry(
      comic: comic,
      heroTag: heroTag,
      revision: _revision,
    );
    _pendingPanelRevealRevision = shouldAnimatePanelReveal ? _revision : null;
    notifyListeners();
  }

  void close() {
    if (_entry == null) {
      return;
    }
    _entry = null;
    _pendingPanelRevealRevision = null;
    notifyListeners();
  }

  Future<void> closeAndWait() async {
    if (_entry == null) {
      return;
    }
    close();
    await Future<void>.delayed(windowsComicDetailPanelAnimationDuration);
  }

  Future<T> hideWhile<T>(Future<T> Function() action) async {
    if (_entry == null) {
      return action();
    }

    _temporaryHideDepth += 1;
    notifyListeners();
    try {
      return await action();
    } finally {
      _temporaryHideDepth -= 1;
      notifyListeners();
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
    WindowsComicDetailController.instance.open(comic, heroTag);
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
