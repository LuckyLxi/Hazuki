import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hazuki/services/manga_download/manga_download_service.dart';

class AnimatedDownloadedComicEntry {
  const AnimatedDownloadedComicEntry({
    required this.comic,
    this.entering = false,
    this.exiting = false,
  });

  final DownloadedMangaComic comic;
  final bool entering;
  final bool exiting;

  AnimatedDownloadedComicEntry copyWith({
    DownloadedMangaComic? comic,
    bool? entering,
    bool? exiting,
  }) => AnimatedDownloadedComicEntry(
    comic: comic ?? this.comic,
    entering: entering ?? this.entering,
    exiting: exiting ?? this.exiting,
  );
}

/// Owns list-diff and enter/exit timing independently from the widget tree.
class DownloadsCompletedListController extends ChangeNotifier {
  DownloadsCompletedListController({
    required List<DownloadedMangaComic> comics,
    required this.transitionDuration,
  }) : _currentComics = List.unmodifiable(comics),
       _entries = comics
           .map((comic) => AnimatedDownloadedComicEntry(comic: comic))
           .toList(growable: false);

  final Duration transitionDuration;
  List<DownloadedMangaComic> _currentComics;
  List<AnimatedDownloadedComicEntry> _entries;
  bool _disposed = false;

  List<AnimatedDownloadedComicEntry> get entries => _entries;

  void sync(List<DownloadedMangaComic> comics) {
    _currentComics = List.unmodifiable(comics);
    final nextById = <String, DownloadedMangaComic>{
      for (final comic in comics) comic.storageKey: comic,
    };
    final currentById = <String, AnimatedDownloadedComicEntry>{
      for (final entry in _entries) entry.comic.storageKey: entry,
    };
    final exitingEntries =
        <({int index, AnimatedDownloadedComicEntry entry})>[];
    final nextVisible = <AnimatedDownloadedComicEntry>[];

    for (var index = 0; index < _entries.length; index++) {
      final entry = _entries[index];
      if (!nextById.containsKey(entry.comic.storageKey)) {
        exitingEntries.add((
          index: index,
          entry: entry.copyWith(exiting: true, entering: false),
        ));
        if (!entry.exiting) _scheduleRemoval(entry.comic.storageKey);
      }
    }

    for (final comic in comics) {
      final currentEntry = currentById[comic.storageKey];
      if (currentEntry == null) {
        nextVisible.add(
          AnimatedDownloadedComicEntry(comic: comic, entering: true),
        );
        _scheduleEnterComplete(comic.storageKey);
      } else {
        nextVisible.add(
          AnimatedDownloadedComicEntry(
            comic: comic,
            entering: currentEntry.entering,
          ),
        );
      }
    }

    for (final exiting in exitingEntries) {
      nextVisible.insert(
        exiting.index.clamp(0, nextVisible.length),
        exiting.entry,
      );
    }
    _replaceIfChanged(nextVisible);
  }

  void _scheduleEnterComplete(String storageKey) {
    unawaited(
      Future<void>.delayed(transitionDuration, () {
        if (_disposed) return;
        _replaceIfChanged(
          _entries
              .map((entry) {
                if (entry.comic.storageKey != storageKey || entry.exiting) {
                  return entry;
                }
                return entry.copyWith(entering: false);
              })
              .toList(growable: false),
        );
      }),
    );
  }

  void _scheduleRemoval(String storageKey) {
    unawaited(
      Future<void>.delayed(transitionDuration, () {
        if (_disposed ||
            _currentComics.any((comic) => comic.storageKey == storageKey)) {
          return;
        }
        _replaceIfChanged(
          _entries
              .where((entry) => entry.comic.storageKey != storageKey)
              .toList(growable: false),
        );
      }),
    );
  }

  void _replaceIfChanged(List<AnimatedDownloadedComicEntry> next) {
    if (_sameEntries(_entries, next)) return;
    _entries = next;
    notifyListeners();
  }

  bool _sameEntries(
    List<AnimatedDownloadedComicEntry> current,
    List<AnimatedDownloadedComicEntry> next,
  ) {
    if (current.length != next.length) return false;
    for (var index = 0; index < current.length; index++) {
      final a = current[index];
      final b = next[index];
      if (a.comic != b.comic ||
          a.exiting != b.exiting ||
          a.entering != b.entering) {
        return false;
      }
    }
    return true;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
