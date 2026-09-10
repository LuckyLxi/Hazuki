import 'package:flutter/foundation.dart';

import 'storage/hazuki_database.dart' hide DownloadGroup;
import 'download_groups/download_groups_repository.dart';
import 'download_groups/download_groups_persistence.dart';
import 'download_groups/download_groups_snapshot_codec.dart';
import 'download_groups/download_groups_sync_merger.dart';

export 'download_groups/download_group.dart';

class DownloadGroupsService extends ChangeNotifier
    implements DownloadGroupsRepository {
  DownloadGroupsService({required HazukiDatabase database})
    : this.withPersistence(DownloadGroupsPersistence(database));

  DownloadGroupsService.withPersistence(DownloadGroupsPersistence persistence)
    : _store = persistence,
      _syncMerger = DownloadGroupsSyncMerger(persistence);

  static const String defaultGroupId = DownloadGroup.defaultGroupId;
  static const String defaultGroupName = DownloadGroup.defaultGroupName;

  final DownloadGroupsPersistence _store;
  final DownloadGroupsSyncMerger _syncMerger;
  static const _codec = DownloadGroupsSnapshotCodec();
  int _nextGroupId = 0;
  List<DownloadGroup> _groups = const [];
  Map<String, Set<String>> _comicKeysByGroup = const {};

  @override
  List<DownloadGroup> get groups => List.unmodifiable(_groups);

  @override
  Set<String> comicKeysForGroup(String groupId) =>
      Set.unmodifiable(_comicKeysByGroup[groupId] ?? const <String>{});

  @override
  bool groupContainsComic(String groupId, String comicStorageKey) =>
      _comicKeysByGroup[groupId]?.contains(comicStorageKey) ?? false;

  @override
  Set<String> groupIdsForComic(String comicStorageKey) => {
    for (final entry in _comicKeysByGroup.entries)
      if (entry.value.contains(comicStorageKey)) entry.key,
  };

  @override
  Future<void> initialize(
    Iterable<String> downloadedComicKeys, {
    Map<String, String> migratedComicKeys = const {},
  }) async {
    await _ensureDefaultGroup();
    await reconcileDownloadedComics(
      downloadedComicKeys,
      migratedComicKeys: migratedComicKeys,
      notify: false,
    );
    await reload();
  }

  @override
  Future<void> reconcileDownloadedComics(
    Iterable<String> downloadedComicKeys, {
    Map<String, String> migratedComicKeys = const {},
    bool notify = true,
  }) async {
    final keys = downloadedComicKeys
        .map((key) => key.trim())
        .where((key) => key.isNotEmpty)
        .toSet();
    await _store.transaction(() async {
      await _migrateComicMemberships(migratedComicKeys);
      final memberships = await _store.loadMemberships();
      final knownKeys = memberships.map((item) => item.comicStorageKey).toSet();
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final key in keys.difference(knownKeys)) {
        await _store.putMembership(defaultGroupId, key, now);
      }
      // Missing local downloads may be remote-only or temporarily unavailable.
      // Only explicit deletion should remove memberships and create tombstones.
    });
    if (notify) {
      await reload();
    }
  }

  Future<void> _migrateComicMemberships(
    Map<String, String> migratedComicKeys,
  ) async {
    for (final entry in migratedComicKeys.entries) {
      final oldKey = entry.key.trim();
      final newKey = entry.value.trim();
      if (oldKey.isEmpty || newKey.isEmpty || oldKey == newKey) {
        continue;
      }
      final oldMemberships = await _store.loadMemberships(comicKeys: [oldKey]);
      if (oldMemberships.isEmpty) {
        continue;
      }
      for (final membership in oldMemberships) {
        if (await _store.membershipDeletedAt(membership.groupId, newKey) >=
            membership.addedAtMs) {
          continue;
        }
        final existing = await _store.findMembership(
          membership.groupId,
          newKey,
        );
        if (existing == null || existing.addedAtMs < membership.addedAtMs) {
          await _store.putMembership(
            membership.groupId,
            newKey,
            membership.addedAtMs,
          );
        }
      }
      await _store.deleteMemberships(comicKeys: [oldKey]);
    }
  }

  @override
  Future<DownloadGroup> createGroup(String rawName) async {
    final name = rawName.trim();
    if (name.isEmpty) {
      throw ArgumentError.value(rawName, 'name');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final nextSortOrder =
        _groups
            .where((group) => !group.isDefault)
            .fold<int>(
              0,
              (value, group) =>
                  value > group.sortOrder ? value : group.sortOrder,
            ) +
        1;
    final id =
        'group_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}_${_nextGroupId++}';
    await _store.putGroup(
      DownloadGroup(
        id: id,
        name: name,
        createdAtMs: now,
        sortOrder: nextSortOrder,
      ),
      insertOnly: true,
    );
    await reload();
    return DownloadGroup(
      id: id,
      name: name,
      createdAtMs: now,
      sortOrder: nextSortOrder,
    );
  }

  @override
  Future<DownloadGroup> renameGroup(String groupId, String rawName) async {
    if (groupId == defaultGroupId) {
      throw ArgumentError.value(groupId, 'groupId');
    }
    final name = rawName.trim();
    if (name.isEmpty) {
      throw ArgumentError.value(rawName, 'name');
    }
    await _store.renameGroup(groupId, name);
    await reload();
    return _groups.firstWhere((group) => group.id == groupId);
  }

  @override
  Future<void> reorderGroups(Iterable<String> orderedGroupIds) async {
    final ids = orderedGroupIds
        .where((id) => id != defaultGroupId)
        .toList(growable: false);
    await _store.transaction(() async {
      for (var index = 0; index < ids.length; index++) {
        await _store.setSortOrder(ids[index], index + 1);
      }
    });
    await reload();
  }

  @override
  Future<void> deleteGroup(String groupId) async {
    if (groupId == defaultGroupId) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _store.transaction(() async {
      final memberships = await _store.loadMemberships(groupId: groupId);
      for (final membership in memberships) {
        await _store.putMembership(
          defaultGroupId,
          membership.comicStorageKey,
          now,
        );
        await _store.putMembershipTombstone(
          groupId,
          membership.comicStorageKey,
          now,
        );
      }
      await _store.deleteMemberships(groupId: groupId);
      await _store.deleteGroup(groupId);
      await _store.putGroupTombstone(groupId, now);
    });
    await reload();
  }

  Future<void> addComicToGroup(String comicStorageKey, String groupId) async {
    await _store.putMembership(
      groupId,
      comicStorageKey,
      DateTime.now().millisecondsSinceEpoch,
    );
    await reload();
  }

  Future<void> addComicToGroups(
    String comicStorageKey,
    Iterable<String> groupIds,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _store.transaction(() async {
      for (final groupId in groupIds.toSet()) {
        await _store.putMembership(groupId, comicStorageKey, now);
      }
    });
    await reload();
  }

  @override
  Future<void> addComicsToGroups(
    Iterable<String> comicStorageKeys,
    Iterable<String> groupIds,
  ) async {
    final keys = comicStorageKeys.toSet();
    final targets = groupIds.toSet();
    if (keys.isEmpty || targets.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _store.transaction(() async {
      for (final key in keys) {
        for (final groupId in targets) {
          await _store.putMembership(groupId, key, now);
        }
      }
    });
    await reload();
  }

  @override
  Future<void> removeComicsFromGroup(
    Iterable<String> comicStorageKeys,
    String groupId,
  ) async {
    final keys = comicStorageKeys.toSet();
    if (keys.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _store.transaction(() async {
      final memberships = await _store.loadMemberships(comicKeys: keys);
      final groupIdsByComic = <String, Set<String>>{};
      for (final membership in memberships) {
        groupIdsByComic
            .putIfAbsent(membership.comicStorageKey, () => <String>{})
            .add(membership.groupId);
      }
      for (final key in keys) {
        final existingGroupIds = groupIdsByComic[key];
        if (!(existingGroupIds?.contains(groupId) ?? false)) {
          continue;
        }
        if (groupId == defaultGroupId && existingGroupIds!.length == 1) {
          continue;
        }
        await _store.putMembershipTombstone(groupId, key, now);
        await _store.deleteMemberships(groupId: groupId, comicKeys: [key]);
        final remaining = existingGroupIds!..remove(groupId);
        if (remaining.isEmpty) {
          await _store.putMembership(defaultGroupId, key, now);
        }
      }
    });
    await reload();
  }

  Future<void> moveComicToGroup(String comicStorageKey, String groupId) async {
    await moveComicToGroups(comicStorageKey, [groupId]);
  }

  @override
  Future<void> moveComicToGroups(
    String comicStorageKey,
    Iterable<String> groupIds,
  ) async {
    final targetGroupIds = groupIds.toSet();
    if (targetGroupIds.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _store.transaction(() async {
      final existing = await _store.loadMemberships(
        comicKeys: [comicStorageKey],
      );
      for (final membership in existing) {
        if (!targetGroupIds.contains(membership.groupId)) {
          await _store.putMembershipTombstone(
            membership.groupId,
            comicStorageKey,
            now,
          );
        }
      }
      await _store.deleteMemberships(comicKeys: [comicStorageKey]);
      for (final groupId in targetGroupIds) {
        await _store.putMembership(groupId, comicStorageKey, now);
      }
    });
    await reload();
  }

  Future<void> moveComicsToGroups(
    Iterable<String> comicStorageKeys,
    Iterable<String> groupIds,
  ) async {
    final keys = comicStorageKeys.toSet();
    final targets = groupIds.toSet();
    if (keys.isEmpty || targets.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _store.transaction(() async {
      final existing = await _store.loadMemberships(comicKeys: keys);
      for (final membership in existing) {
        if (!targets.contains(membership.groupId)) {
          await _store.putMembershipTombstone(
            membership.groupId,
            membership.comicStorageKey,
            now,
          );
        }
      }
      await _store.deleteMemberships(comicKeys: keys);
      for (final key in keys) {
        for (final groupId in targets) {
          await _store.putMembership(groupId, key, now);
        }
      }
    });
    await reload();
  }

  Future<void> removeComic(String comicStorageKey) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _store.transaction(() async {
      final existing = await _store.loadMemberships(
        comicKeys: [comicStorageKey],
      );
      for (final membership in existing) {
        await _store.putMembershipTombstone(
          membership.groupId,
          comicStorageKey,
          now,
        );
      }
      await _store.deleteMemberships(comicKeys: [comicStorageKey]);
    });
    await reload();
  }

  Future<String> exportJsonString() async =>
      _codec.encode(await _store.loadSnapshot());

  Future<void> importJsonString(String? raw, {bool replace = false}) async {
    final snapshot = _codec.decode(raw);
    if (snapshot == null) return;
    await _syncMerger.apply(snapshot, replace: replace);
    await _ensureDefaultGroup();
    await reload();
  }

  Future<void> reload() async {
    final groupRows = await _store.loadGroups(sorted: true);
    final membershipRows = await _store.loadMemberships();
    _groups = groupRows;
    final nextMemberships = <String, Set<String>>{};
    for (final row in membershipRows) {
      nextMemberships
          .putIfAbsent(row.groupId, () => <String>{})
          .add(row.comicStorageKey);
    }
    _comicKeysByGroup = nextMemberships;
    notifyListeners();
  }

  Future<void> _ensureDefaultGroup() => _store.putGroup(
    const DownloadGroup(
      id: defaultGroupId,
      name: defaultGroupName,
      createdAtMs: 0,
    ),
  );
}
