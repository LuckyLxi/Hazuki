import 'dart:convert';

import 'download_group.dart';
import 'download_groups_snapshot.dart';

class DownloadGroupsSnapshotCodec {
  const DownloadGroupsSnapshotCodec();

  String encode(DownloadGroupsSnapshot snapshot) => jsonEncode({
    'version': 1,
    'groups': [
      for (final row in snapshot.groups)
        {
          'id': row.id,
          'name': row.name,
          'createdAtMs': row.createdAtMs,
          'sortOrder': row.sortOrder,
        },
    ],
    'memberships': [
      for (final row in snapshot.memberships)
        {
          'groupId': row.groupId,
          'comicStorageKey': row.comicStorageKey,
          'addedAtMs': row.addedAtMs,
        },
    ],
    'groupTombstones': [
      for (final row in snapshot.groupTombstones)
        {'groupId': row.groupId, 'deletedAtMs': row.deletedAtMs},
    ],
    'membershipTombstones': [
      for (final row in snapshot.membershipTombstones)
        {
          'groupId': row.groupId,
          'comicStorageKey': row.comicStorageKey,
          'deletedAtMs': row.deletedAtMs,
        },
    ],
  });

  DownloadGroupsSnapshot? decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    final data = Map<String, dynamic>.from(decoded);
    // Preserve the v1 defaults and validation, including errors for fields of
    // the wrong type. Decode fully before a replace can modify stored data.
    final groups = <DownloadGroup>[];
    final memberships = <DownloadGroupMembership>[];
    final groupTombstones = <DownloadGroupDeletion>[];
    final membershipTombstones = <DownloadGroupMembershipDeletion>[];
    for (final item in _rows(data['groupTombstones'])) {
      final id = (item['groupId'] ?? '').toString();
      final ts = (item['deletedAtMs'] as num?)?.toInt() ?? 0;
      if (id.isEmpty || id == DownloadGroup.defaultGroupId || ts <= 0) continue;
      groupTombstones.add(DownloadGroupDeletion(id, ts));
    }
    for (final item in _rows(data['membershipTombstones'])) {
      final groupId = (item['groupId'] ?? '').toString();
      final key = (item['comicStorageKey'] ?? '').toString();
      final ts = (item['deletedAtMs'] as num?)?.toInt() ?? 0;
      if (groupId.isEmpty || key.isEmpty || ts <= 0) continue;
      membershipTombstones.add(
        DownloadGroupMembershipDeletion(groupId, key, ts),
      );
    }
    for (final item in _rows(data['groups'])) {
      final id = (item['id'] ?? '').toString();
      final name = (item['name'] ?? '').toString().trim();
      final createdAt = (item['createdAtMs'] as num?)?.toInt() ?? 0;
      final sortOrder = (item['sortOrder'] as num?)?.toInt() ?? 0;
      if (id.isEmpty || name.isEmpty) continue;
      groups.add(
        DownloadGroup(
          id: id,
          name: name,
          createdAtMs: createdAt,
          sortOrder: sortOrder,
        ),
      );
    }
    for (final item in _rows(data['memberships'])) {
      final groupId = (item['groupId'] ?? '').toString();
      final key = (item['comicStorageKey'] ?? '').toString();
      final addedAt = (item['addedAtMs'] as num?)?.toInt() ?? 0;
      if (groupId.isEmpty || key.isEmpty) continue;
      memberships.add(DownloadGroupMembership(groupId, key, addedAt));
    }
    return DownloadGroupsSnapshot(
      groups: groups,
      memberships: memberships,
      groupTombstones: groupTombstones,
      membershipTombstones: membershipTombstones,
    );
  }

  Iterable<Map> _rows(dynamic value) sync* {
    for (final item in (value as List? ?? const [])) {
      if (item is Map) yield item;
    }
  }
}
