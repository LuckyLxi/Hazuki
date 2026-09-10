import 'download_group.dart';

class DownloadGroupMembership {
  const DownloadGroupMembership(
    this.groupId,
    this.comicStorageKey,
    this.addedAtMs,
  );

  final String groupId;
  final String comicStorageKey;
  final int addedAtMs;
}

class DownloadGroupDeletion {
  const DownloadGroupDeletion(this.groupId, this.deletedAtMs);

  final String groupId;
  final int deletedAtMs;
}

class DownloadGroupMembershipDeletion {
  const DownloadGroupMembershipDeletion(
    this.groupId,
    this.comicStorageKey,
    this.deletedAtMs,
  );

  final String groupId;
  final String comicStorageKey;
  final int deletedAtMs;
}

class DownloadGroupsSnapshot {
  const DownloadGroupsSnapshot({
    this.groups = const [],
    this.memberships = const [],
    this.groupTombstones = const [],
    this.membershipTombstones = const [],
  });

  final List<DownloadGroup> groups;
  final List<DownloadGroupMembership> memberships;
  final List<DownloadGroupDeletion> groupTombstones;
  final List<DownloadGroupMembershipDeletion> membershipTombstones;
}
