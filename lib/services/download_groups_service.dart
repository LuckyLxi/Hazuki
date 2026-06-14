import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import 'storage/hazuki_database.dart';

class DownloadGroup {
  const DownloadGroup({
    required this.id,
    required this.name,
    required this.createdAtMs,
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final int createdAtMs;
  final int sortOrder;

  bool get isDefault => id == DownloadGroupsService.defaultGroupId;
}

class DownloadGroupsService extends ChangeNotifier {
  DownloadGroupsService({required HazukiDatabase database})
    : _database = database;

  static const String defaultGroupId = 'default';
  static const String defaultGroupName = 'Default';

  final HazukiDatabase _database;
  int _nextGroupId = 0;
  List<DownloadGroup> _groups = const [];
  Map<String, Set<String>> _comicKeysByGroup = const {};

  List<DownloadGroup> get groups => List.unmodifiable(_groups);

  Set<String> comicKeysForGroup(String groupId) =>
      Set.unmodifiable(_comicKeysByGroup[groupId] ?? const <String>{});

  bool groupContainsComic(String groupId, String comicStorageKey) =>
      _comicKeysByGroup[groupId]?.contains(comicStorageKey) ?? false;

  Set<String> groupIdsForComic(String comicStorageKey) => {
    for (final entry in _comicKeysByGroup.entries)
      if (entry.value.contains(comicStorageKey)) entry.key,
  };

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

  Future<void> reconcileDownloadedComics(
    Iterable<String> downloadedComicKeys, {
    Map<String, String> migratedComicKeys = const {},
    bool notify = true,
  }) async {
    final keys = downloadedComicKeys
        .map((key) => key.trim())
        .where((key) => key.isNotEmpty)
        .toSet();
    await _database.transaction(() async {
      await _migrateComicMemberships(migratedComicKeys);
      final memberships = await _database
          .select(_database.downloadGroupComics)
          .get();
      final knownKeys = memberships.map((item) => item.comicStorageKey).toSet();
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final key in keys.difference(knownKeys)) {
        await _putMembership(defaultGroupId, key, now);
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
      final oldMemberships = await (_database.select(
        _database.downloadGroupComics,
      )..where((row) => row.comicStorageKey.equals(oldKey))).get();
      if (oldMemberships.isEmpty) {
        continue;
      }
      for (final membership in oldMemberships) {
        if (await _membershipDeletedAt(membership.groupId, newKey) >=
            membership.addedAtMs) {
          continue;
        }
        final existing =
            await (_database.select(_database.downloadGroupComics)..where(
                  (row) =>
                      row.groupId.equals(membership.groupId) &
                      row.comicStorageKey.equals(newKey),
                ))
                .getSingleOrNull();
        if (existing == null || existing.addedAtMs < membership.addedAtMs) {
          await _putMembership(
            membership.groupId,
            newKey,
            membership.addedAtMs,
          );
        }
      }
      await (_database.delete(
        _database.downloadGroupComics,
      )..where((row) => row.comicStorageKey.equals(oldKey))).go();
    }
  }

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
    await _database
        .into(_database.downloadGroups)
        .insert(
          DownloadGroupsCompanion.insert(
            id: id,
            name: name,
            createdAtMs: now,
            sortOrder: Value(nextSortOrder),
          ),
        );
    await reload();
    return DownloadGroup(
      id: id,
      name: name,
      createdAtMs: now,
      sortOrder: nextSortOrder,
    );
  }

  Future<DownloadGroup> renameGroup(String groupId, String rawName) async {
    if (groupId == defaultGroupId) {
      throw ArgumentError.value(groupId, 'groupId');
    }
    final name = rawName.trim();
    if (name.isEmpty) {
      throw ArgumentError.value(rawName, 'name');
    }
    await (_database.update(_database.downloadGroups)
          ..where((row) => row.id.equals(groupId)))
        .write(DownloadGroupsCompanion(name: Value(name)));
    await reload();
    return _groups.firstWhere((group) => group.id == groupId);
  }

  Future<void> reorderGroups(Iterable<String> orderedGroupIds) async {
    final ids = orderedGroupIds
        .where((id) => id != defaultGroupId)
        .toList(growable: false);
    await _database.transaction(() async {
      for (var index = 0; index < ids.length; index++) {
        await (_database.update(_database.downloadGroups)
              ..where((row) => row.id.equals(ids[index])))
            .write(DownloadGroupsCompanion(sortOrder: Value(index + 1)));
      }
    });
    await reload();
  }

  Future<void> deleteGroup(String groupId) async {
    if (groupId == defaultGroupId) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _database.transaction(() async {
      final memberships = await (_database.select(
        _database.downloadGroupComics,
      )..where((row) => row.groupId.equals(groupId))).get();
      for (final membership in memberships) {
        await _putMembership(defaultGroupId, membership.comicStorageKey, now);
        await _putMembershipTombstone(groupId, membership.comicStorageKey, now);
      }
      await (_database.delete(
        _database.downloadGroupComics,
      )..where((row) => row.groupId.equals(groupId))).go();
      await (_database.delete(
        _database.downloadGroups,
      )..where((row) => row.id.equals(groupId))).go();
      await _database
          .into(_database.downloadGroupTombstones)
          .insertOnConflictUpdate(
            DownloadGroupTombstonesCompanion.insert(
              groupId: groupId,
              deletedAtMs: now,
            ),
          );
    });
    await reload();
  }

  Future<void> addComicToGroup(String comicStorageKey, String groupId) async {
    await _putMembership(
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
    await _database.transaction(() async {
      for (final groupId in groupIds.toSet()) {
        await _putMembership(groupId, comicStorageKey, now);
      }
    });
    await reload();
  }

  Future<void> addComicsToGroups(
    Iterable<String> comicStorageKeys,
    Iterable<String> groupIds,
  ) async {
    final keys = comicStorageKeys.toSet();
    final targets = groupIds.toSet();
    if (keys.isEmpty || targets.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _database.transaction(() async {
      for (final key in keys) {
        for (final groupId in targets) {
          await _putMembership(groupId, key, now);
        }
      }
    });
    await reload();
  }

  Future<void> removeComicsFromGroup(
    Iterable<String> comicStorageKeys,
    String groupId,
  ) async {
    final keys = comicStorageKeys.toSet();
    if (keys.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _database.transaction(() async {
      final memberships = await (_database.select(
        _database.downloadGroupComics,
      )..where((row) => row.comicStorageKey.isIn(keys))).get();
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
        await _putMembershipTombstone(groupId, key, now);
        await (_database.delete(_database.downloadGroupComics)..where(
              (row) =>
                  row.groupId.equals(groupId) & row.comicStorageKey.equals(key),
            ))
            .go();
        final remaining = existingGroupIds!..remove(groupId);
        if (remaining.isEmpty) {
          await _putMembership(defaultGroupId, key, now);
        }
      }
    });
    await reload();
  }

  Future<void> moveComicToGroup(String comicStorageKey, String groupId) async {
    await moveComicToGroups(comicStorageKey, [groupId]);
  }

  Future<void> moveComicToGroups(
    String comicStorageKey,
    Iterable<String> groupIds,
  ) async {
    final targetGroupIds = groupIds.toSet();
    if (targetGroupIds.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _database.transaction(() async {
      final existing = await (_database.select(
        _database.downloadGroupComics,
      )..where((row) => row.comicStorageKey.equals(comicStorageKey))).get();
      for (final membership in existing) {
        if (!targetGroupIds.contains(membership.groupId)) {
          await _putMembershipTombstone(
            membership.groupId,
            comicStorageKey,
            now,
          );
        }
      }
      await (_database.delete(
        _database.downloadGroupComics,
      )..where((row) => row.comicStorageKey.equals(comicStorageKey))).go();
      for (final groupId in targetGroupIds) {
        await _putMembership(groupId, comicStorageKey, now);
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
    await _database.transaction(() async {
      final existing = await (_database.select(
        _database.downloadGroupComics,
      )..where((row) => row.comicStorageKey.isIn(keys))).get();
      for (final membership in existing) {
        if (!targets.contains(membership.groupId)) {
          await _putMembershipTombstone(
            membership.groupId,
            membership.comicStorageKey,
            now,
          );
        }
      }
      await (_database.delete(
        _database.downloadGroupComics,
      )..where((row) => row.comicStorageKey.isIn(keys))).go();
      for (final key in keys) {
        for (final groupId in targets) {
          await _putMembership(groupId, key, now);
        }
      }
    });
    await reload();
  }

  Future<void> removeComic(String comicStorageKey) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _database.transaction(() async {
      final existing = await (_database.select(
        _database.downloadGroupComics,
      )..where((row) => row.comicStorageKey.equals(comicStorageKey))).get();
      for (final membership in existing) {
        await _putMembershipTombstone(membership.groupId, comicStorageKey, now);
      }
      await (_database.delete(
        _database.downloadGroupComics,
      )..where((row) => row.comicStorageKey.equals(comicStorageKey))).go();
    });
    await reload();
  }

  Future<String> exportJsonString() async {
    final groups = await _database.select(_database.downloadGroups).get();
    final memberships = await _database
        .select(_database.downloadGroupComics)
        .get();
    final groupTombstones = await _database
        .select(_database.downloadGroupTombstones)
        .get();
    final membershipTombstones = await _database
        .select(_database.downloadGroupComicTombstones)
        .get();
    return jsonEncode({
      'version': 1,
      'groups': [
        for (final row in groups)
          {
            'id': row.id,
            'name': row.name,
            'createdAtMs': row.createdAtMs,
            'sortOrder': row.sortOrder,
          },
      ],
      'memberships': [
        for (final row in memberships)
          {
            'groupId': row.groupId,
            'comicStorageKey': row.comicStorageKey,
            'addedAtMs': row.addedAtMs,
          },
      ],
      'groupTombstones': [
        for (final row in groupTombstones)
          {'groupId': row.groupId, 'deletedAtMs': row.deletedAtMs},
      ],
      'membershipTombstones': [
        for (final row in membershipTombstones)
          {
            'groupId': row.groupId,
            'comicStorageKey': row.comicStorageKey,
            'deletedAtMs': row.deletedAtMs,
          },
      ],
    });
  }

  Future<void> importJsonString(String? raw, {bool replace = false}) async {
    if (raw == null || raw.trim().isEmpty) return;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return;
    final data = Map<String, dynamic>.from(decoded);
    await _database.transaction(() async {
      if (replace) {
        await _database.delete(_database.downloadGroupComics).go();
        await _database.delete(_database.downloadGroups).go();
        await _database.delete(_database.downloadGroupTombstones).go();
        await _database.delete(_database.downloadGroupComicTombstones).go();
      }
      for (final item in (data['groupTombstones'] as List? ?? const [])) {
        if (item is! Map) continue;
        final id = (item['groupId'] ?? '').toString();
        final ts = (item['deletedAtMs'] as num?)?.toInt() ?? 0;
        if (id.isEmpty || id == defaultGroupId || ts <= 0) continue;
        if (await _groupDeletedAt(id) < ts) {
          await _database
              .into(_database.downloadGroupTombstones)
              .insertOnConflictUpdate(
                DownloadGroupTombstonesCompanion.insert(
                  groupId: id,
                  deletedAtMs: ts,
                ),
              );
        }
      }
      for (final item in (data['membershipTombstones'] as List? ?? const [])) {
        if (item is! Map) continue;
        final groupId = (item['groupId'] ?? '').toString();
        final key = (item['comicStorageKey'] ?? '').toString();
        final ts = (item['deletedAtMs'] as num?)?.toInt() ?? 0;
        if (groupId.isEmpty || key.isEmpty || ts <= 0) continue;
        if (await _membershipDeletedAt(groupId, key) < ts) {
          await _putMembershipTombstone(groupId, key, ts);
        }
      }
      for (final item in (data['groups'] as List? ?? const [])) {
        if (item is! Map) continue;
        final id = (item['id'] ?? '').toString();
        final name = (item['name'] ?? '').toString().trim();
        final createdAt = (item['createdAtMs'] as num?)?.toInt() ?? 0;
        final sortOrder = (item['sortOrder'] as num?)?.toInt() ?? 0;
        if (id.isEmpty || name.isEmpty) continue;
        final deletedAt = await _groupDeletedAt(id);
        if (id != defaultGroupId && deletedAt >= createdAt) continue;
        final existing = await (_database.select(
          _database.downloadGroups,
        )..where((row) => row.id.equals(id))).getSingleOrNull();
        if (existing != null && existing.createdAtMs > createdAt) continue;
        await _database
            .into(_database.downloadGroups)
            .insertOnConflictUpdate(
              DownloadGroupsCompanion.insert(
                id: id,
                name: name,
                createdAtMs: createdAt,
                sortOrder: Value(sortOrder),
              ),
            );
      }
      for (final item in (data['memberships'] as List? ?? const [])) {
        if (item is! Map) continue;
        final groupId = (item['groupId'] ?? '').toString();
        final key = (item['comicStorageKey'] ?? '').toString();
        final addedAt = (item['addedAtMs'] as num?)?.toInt() ?? 0;
        if (groupId.isEmpty || key.isEmpty) continue;
        if (await _groupDeletedAt(groupId) >= addedAt) continue;
        if (await _membershipDeletedAt(groupId, key) >= addedAt) continue;
        final existing =
            await (_database.select(_database.downloadGroupComics)..where(
                  (row) =>
                      row.groupId.equals(groupId) &
                      row.comicStorageKey.equals(key),
                ))
                .getSingleOrNull();
        if (existing != null && existing.addedAtMs > addedAt) continue;
        await _putMembership(groupId, key, addedAt);
      }
      final deletedMemberships = await _database
          .select(_database.downloadGroupComicTombstones)
          .get();
      for (final tombstone in deletedMemberships) {
        await (_database.delete(_database.downloadGroupComics)..where(
              (row) =>
                  row.groupId.equals(tombstone.groupId) &
                  row.comicStorageKey.equals(tombstone.comicStorageKey) &
                  row.addedAtMs.isSmallerOrEqualValue(tombstone.deletedAtMs),
            ))
            .go();
      }
      final deletedGroups = await _database
          .select(_database.downloadGroupTombstones)
          .get();
      for (final tombstone in deletedGroups) {
        final memberships = await (_database.select(
          _database.downloadGroupComics,
        )..where((row) => row.groupId.equals(tombstone.groupId))).get();
        for (final membership in memberships) {
          await _putMembership(
            defaultGroupId,
            membership.comicStorageKey,
            tombstone.deletedAtMs,
          );
        }
        await (_database.delete(_database.downloadGroups)..where(
              (row) =>
                  row.id.equals(tombstone.groupId) &
                  row.createdAtMs.isSmallerOrEqualValue(tombstone.deletedAtMs),
            ))
            .go();
        await (_database.delete(
          _database.downloadGroupComics,
        )..where((row) => row.groupId.equals(tombstone.groupId))).go();
      }
    });
    await _ensureDefaultGroup();
    await reload();
  }

  Future<void> reload() async {
    final groupRows =
        await (_database.select(_database.downloadGroups)..orderBy([
              (row) => OrderingTerm.asc(row.sortOrder),
              (row) => OrderingTerm.asc(row.createdAtMs),
              (row) => OrderingTerm.asc(row.name),
            ]))
            .get();
    final membershipRows = await _database
        .select(_database.downloadGroupComics)
        .get();
    _groups = [
      for (final row in groupRows)
        DownloadGroup(
          id: row.id,
          name: row.name,
          createdAtMs: row.createdAtMs,
          sortOrder: row.sortOrder,
        ),
    ];
    final nextMemberships = <String, Set<String>>{};
    for (final row in membershipRows) {
      nextMemberships
          .putIfAbsent(row.groupId, () => <String>{})
          .add(row.comicStorageKey);
    }
    _comicKeysByGroup = nextMemberships;
    notifyListeners();
  }

  Future<void> _ensureDefaultGroup() async {
    await _database
        .into(_database.downloadGroups)
        .insertOnConflictUpdate(
          DownloadGroupsCompanion.insert(
            id: defaultGroupId,
            name: defaultGroupName,
            createdAtMs: 0,
            sortOrder: const Value(0),
          ),
        );
  }

  Future<void> _putMembership(String groupId, String key, int addedAtMs) async {
    await _database
        .into(_database.downloadGroupComics)
        .insertOnConflictUpdate(
          DownloadGroupComicsCompanion.insert(
            groupId: groupId,
            comicStorageKey: key,
            addedAtMs: addedAtMs,
          ),
        );
  }

  Future<void> _putMembershipTombstone(
    String groupId,
    String key,
    int deletedAtMs,
  ) async {
    await _database
        .into(_database.downloadGroupComicTombstones)
        .insertOnConflictUpdate(
          DownloadGroupComicTombstonesCompanion.insert(
            groupId: groupId,
            comicStorageKey: key,
            deletedAtMs: deletedAtMs,
          ),
        );
  }

  Future<int> _groupDeletedAt(String groupId) async {
    final row = await (_database.select(
      _database.downloadGroupTombstones,
    )..where((item) => item.groupId.equals(groupId))).getSingleOrNull();
    return row?.deletedAtMs ?? -1;
  }

  Future<int> _membershipDeletedAt(String groupId, String key) async {
    final row =
        await (_database.select(_database.downloadGroupComicTombstones)..where(
              (item) =>
                  item.groupId.equals(groupId) &
                  item.comicStorageKey.equals(key),
            ))
            .getSingleOrNull();
    return row?.deletedAtMs ?? -1;
  }
}
