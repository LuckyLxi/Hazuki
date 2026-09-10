import 'package:drift/drift.dart';

import '../storage/hazuki_database.dart' as db;
import 'download_group.dart';
import 'download_groups_snapshot.dart';

/// All database queries for download groups. Callers own the business rules
/// and use transaction() to keep multi-step edits atomic.
class DownloadGroupsPersistence {
  DownloadGroupsPersistence(this._database);

  final db.HazukiDatabase _database;

  Future<T> transaction<T>(Future<T> Function() action) =>
      _database.transaction(action);

  Future<List<DownloadGroup>> loadGroups({bool sorted = false}) async {
    final query = _database.select(_database.downloadGroups);
    if (sorted) {
      query.orderBy([
        (row) => OrderingTerm.asc(row.sortOrder),
        (row) => OrderingTerm.asc(row.createdAtMs),
        (row) => OrderingTerm.asc(row.name),
      ]);
    }
    return [for (final row in await query.get()) _group(row)];
  }

  Future<DownloadGroup?> findGroup(String id) async {
    final row = await (_database.select(
      _database.downloadGroups,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    return row == null ? null : _group(row);
  }

  DownloadGroup _group(db.DownloadGroup row) => DownloadGroup(
    id: row.id,
    name: row.name,
    createdAtMs: row.createdAtMs,
    sortOrder: row.sortOrder,
  );

  Future<void> putGroup(DownloadGroup group, {bool insertOnly = false}) async {
    final row = db.DownloadGroupsCompanion.insert(
      id: group.id,
      name: group.name,
      createdAtMs: group.createdAtMs,
      sortOrder: Value(group.sortOrder),
    );
    final table = _database.into(_database.downloadGroups);
    if (insertOnly) {
      await table.insert(row);
    } else {
      await table.insertOnConflictUpdate(row);
    }
  }

  Future<void> renameGroup(String id, String name) async {
    await (_database.update(_database.downloadGroups)
          ..where((row) => row.id.equals(id)))
        .write(db.DownloadGroupsCompanion(name: Value(name)));
  }

  Future<void> setSortOrder(String id, int order) async {
    await (_database.update(_database.downloadGroups)
          ..where((row) => row.id.equals(id)))
        .write(db.DownloadGroupsCompanion(sortOrder: Value(order)));
  }

  Future<void> deleteGroup(String id, {int? createdBeforeOrAt}) async {
    final query = _database.delete(_database.downloadGroups)
      ..where((row) => row.id.equals(id));
    if (createdBeforeOrAt != null) {
      query.where(
        (row) => row.createdAtMs.isSmallerOrEqualValue(createdBeforeOrAt),
      );
    }
    await query.go();
  }

  Future<List<DownloadGroupMembership>> loadMemberships({
    String? groupId,
    Iterable<String>? comicKeys,
  }) async {
    final query = _database.select(_database.downloadGroupComics);
    if (groupId != null) query.where((row) => row.groupId.equals(groupId));
    if (comicKeys != null) {
      query.where((row) => row.comicStorageKey.isIn(comicKeys));
    }
    return [
      for (final row in await query.get())
        DownloadGroupMembership(
          row.groupId,
          row.comicStorageKey,
          row.addedAtMs,
        ),
    ];
  }

  Future<DownloadGroupMembership?> findMembership(
    String groupId,
    String key,
  ) async {
    final rows = await loadMemberships(groupId: groupId, comicKeys: [key]);
    return rows.isEmpty ? null : rows.single;
  }

  Future<void> putMembership(String groupId, String key, int addedAtMs) async {
    await _database
        .into(_database.downloadGroupComics)
        .insertOnConflictUpdate(
          db.DownloadGroupComicsCompanion.insert(
            groupId: groupId,
            comicStorageKey: key,
            addedAtMs: addedAtMs,
          ),
        );
  }

  Future<void> deleteMemberships({
    String? groupId,
    Iterable<String>? comicKeys,
    int? addedBeforeOrAt,
  }) async {
    final query = _database.delete(_database.downloadGroupComics);
    if (groupId != null) query.where((row) => row.groupId.equals(groupId));
    if (comicKeys != null) {
      query.where((row) => row.comicStorageKey.isIn(comicKeys));
    }
    if (addedBeforeOrAt != null) {
      query.where(
        (row) => row.addedAtMs.isSmallerOrEqualValue(addedBeforeOrAt),
      );
    }
    await query.go();
  }

  Future<List<DownloadGroupDeletion>> loadGroupTombstones() async => [
    for (final row
        in await _database.select(_database.downloadGroupTombstones).get())
      DownloadGroupDeletion(row.groupId, row.deletedAtMs),
  ];

  Future<List<DownloadGroupMembershipDeletion>>
  loadMembershipTombstones() async => [
    for (final row
        in await _database.select(_database.downloadGroupComicTombstones).get())
      DownloadGroupMembershipDeletion(
        row.groupId,
        row.comicStorageKey,
        row.deletedAtMs,
      ),
  ];

  Future<void> putGroupTombstone(String groupId, int deletedAtMs) async {
    await _database
        .into(_database.downloadGroupTombstones)
        .insertOnConflictUpdate(
          db.DownloadGroupTombstonesCompanion.insert(
            groupId: groupId,
            deletedAtMs: deletedAtMs,
          ),
        );
  }

  Future<void> putMembershipTombstone(
    String groupId,
    String key,
    int deletedAtMs,
  ) async {
    await _database
        .into(_database.downloadGroupComicTombstones)
        .insertOnConflictUpdate(
          db.DownloadGroupComicTombstonesCompanion.insert(
            groupId: groupId,
            comicStorageKey: key,
            deletedAtMs: deletedAtMs,
          ),
        );
  }

  Future<int> groupDeletedAt(String groupId) async {
    final row = await (_database.select(
      _database.downloadGroupTombstones,
    )..where((row) => row.groupId.equals(groupId))).getSingleOrNull();
    return row?.deletedAtMs ?? -1;
  }

  Future<int> membershipDeletedAt(String groupId, String key) async {
    final row =
        await (_database.select(_database.downloadGroupComicTombstones)..where(
              (row) =>
                  row.groupId.equals(groupId) & row.comicStorageKey.equals(key),
            ))
            .getSingleOrNull();
    return row?.deletedAtMs ?? -1;
  }

  Future<DownloadGroupsSnapshot> loadSnapshot() async => DownloadGroupsSnapshot(
    groups: await loadGroups(),
    memberships: await loadMemberships(),
    groupTombstones: await loadGroupTombstones(),
    membershipTombstones: await loadMembershipTombstones(),
  );

  Future<void> clear() async {
    await _database.delete(_database.downloadGroupComics).go();
    await _database.delete(_database.downloadGroups).go();
    await _database.delete(_database.downloadGroupTombstones).go();
    await _database.delete(_database.downloadGroupComicTombstones).go();
  }
}
