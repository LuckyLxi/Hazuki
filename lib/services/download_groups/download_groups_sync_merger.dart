import 'download_group.dart';
import 'download_groups_persistence.dart';
import 'download_groups_snapshot.dart';

/// Applies the existing v1 timestamp and deletion rules in one transaction.
/// JSON decoding and UI notifications are deliberately outside this component.
class DownloadGroupsSyncMerger {
  const DownloadGroupsSyncMerger(this._store);

  final DownloadGroupsPersistence _store;

  Future<void> apply(
    DownloadGroupsSnapshot snapshot, {
    bool replace = false,
  }) async {
    await _store.transaction(() async {
      if (replace) await _store.clear();
      for (final item in snapshot.groupTombstones) {
        if (await _store.groupDeletedAt(item.groupId) < item.deletedAtMs) {
          await _store.putGroupTombstone(item.groupId, item.deletedAtMs);
        }
      }
      for (final item in snapshot.membershipTombstones) {
        if (await _store.membershipDeletedAt(
              item.groupId,
              item.comicStorageKey,
            ) <
            item.deletedAtMs) {
          await _store.putMembershipTombstone(
            item.groupId,
            item.comicStorageKey,
            item.deletedAtMs,
          );
        }
      }
      for (final group in snapshot.groups) {
        final deletedAt = await _store.groupDeletedAt(group.id);
        if (group.id != DownloadGroup.defaultGroupId &&
            deletedAt >= group.createdAtMs) {
          continue;
        }
        final existing = await _store.findGroup(group.id);
        if (existing != null && existing.createdAtMs > group.createdAtMs) {
          continue;
        }
        await _store.putGroup(group);
      }
      for (final membership in snapshot.memberships) {
        final groupId = membership.groupId;
        final key = membership.comicStorageKey;
        final addedAt = membership.addedAtMs;
        if (await _store.groupDeletedAt(groupId) >= addedAt) continue;
        if (await _store.membershipDeletedAt(groupId, key) >= addedAt) continue;
        final existing = await _store.findMembership(groupId, key);
        if (existing != null && existing.addedAtMs > addedAt) continue;
        await _store.putMembership(groupId, key, addedAt);
      }
      for (final tombstone in await _store.loadMembershipTombstones()) {
        await _store.deleteMemberships(
          groupId: tombstone.groupId,
          comicKeys: [tombstone.comicStorageKey],
          addedBeforeOrAt: tombstone.deletedAtMs,
        );
      }
      // Preserve the v1 order: remove deleted memberships first, then move
      // memberships of tombstoned groups into the default group.
      for (final tombstone in await _store.loadGroupTombstones()) {
        final memberships = await _store.loadMemberships(
          groupId: tombstone.groupId,
        );
        for (final membership in memberships) {
          await _store.putMembership(
            DownloadGroup.defaultGroupId,
            membership.comicStorageKey,
            tombstone.deletedAtMs,
          );
        }
        await _store.deleteGroup(
          tombstone.groupId,
          createdBeforeOrAt: tombstone.deletedAtMs,
        );
        await _store.deleteMemberships(groupId: tombstone.groupId);
      }
    });
  }
}
