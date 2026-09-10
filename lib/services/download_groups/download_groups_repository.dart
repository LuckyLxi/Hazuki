import 'package:flutter/foundation.dart';

import 'download_group.dart';

export 'download_group.dart';

/// Group queries and edits used by download management. Persistence and cloud
/// sync formats are owned by the implementation.
abstract interface class DownloadGroupsRepository implements Listenable {
  List<DownloadGroup> get groups;
  Set<String> comicKeysForGroup(String groupId);
  bool groupContainsComic(String groupId, String comicStorageKey);
  Set<String> groupIdsForComic(String comicStorageKey);

  Future<void> initialize(
    Iterable<String> downloadedComicKeys, {
    Map<String, String> migratedComicKeys = const {},
  });
  Future<void> reconcileDownloadedComics(
    Iterable<String> downloadedComicKeys, {
    Map<String, String> migratedComicKeys = const {},
  });
  Future<DownloadGroup> createGroup(String rawName);
  Future<DownloadGroup> renameGroup(String groupId, String rawName);
  Future<void> reorderGroups(Iterable<String> orderedGroupIds);
  Future<void> deleteGroup(String groupId);
  Future<void> addComicsToGroups(
    Iterable<String> comicStorageKeys,
    Iterable<String> groupIds,
  );
  Future<void> removeComicsFromGroup(
    Iterable<String> comicStorageKeys,
    String groupId,
  );
  Future<void> moveComicToGroups(
    String comicStorageKey,
    Iterable<String> groupIds,
  );
}
