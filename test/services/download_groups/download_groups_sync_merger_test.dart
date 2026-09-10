import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/download_groups/download_groups_persistence.dart';
import 'package:hazuki/services/download_groups/download_groups_snapshot.dart';
import 'package:hazuki/services/download_groups/download_groups_sync_merger.dart';
import 'package:hazuki/services/download_groups_service.dart';
import 'package:hazuki/services/storage/hazuki_database.dart'
    hide DownloadGroup;

void main() {
  late HazukiDatabase database;
  late DownloadGroupsPersistence store;
  late DownloadGroupsSyncMerger merger;

  setUp(() {
    database = HazukiDatabase.memory();
    store = DownloadGroupsPersistence(database);
    merger = DownloadGroupsSyncMerger(store);
  });
  tearDown(() => database.close());

  test(
    'newer local records survive and equal timestamps accept remote groups',
    () async {
      await store.putGroup(
        const DownloadGroup(id: 'g', name: 'Local', createdAtMs: 20),
      );
      await store.putMembership('g', 'a', 20);
      await merger.apply(
        const DownloadGroupsSnapshot(
          groups: [DownloadGroup(id: 'g', name: 'Old', createdAtMs: 10)],
          memberships: [DownloadGroupMembership('g', 'a', 10)],
        ),
      );
      expect((await store.findGroup('g'))!.name, 'Local');
      expect((await store.findMembership('g', 'a'))!.addedAtMs, 20);

      await merger.apply(
        const DownloadGroupsSnapshot(
          groups: [
            DownloadGroup(
              id: 'g',
              name: 'Remote',
              createdAtMs: 20,
              sortOrder: 3,
            ),
          ],
        ),
      );
      expect((await store.findGroup('g'))!.name, 'Remote');
      expect((await store.findGroup('g'))!.sortOrder, 3);
    },
  );

  test(
    'membership deletion wins ties without deleting newer or unrelated rows',
    () async {
      await store.putMembership('g', 'equal', 20);
      await store.putMembership('g', 'newer', 21);
      await store.putMembership('other', 'equal', 5);
      await merger.apply(
        const DownloadGroupsSnapshot(
          memberships: [DownloadGroupMembership('g', 'equal', 20)],
          membershipTombstones: [
            DownloadGroupMembershipDeletion('g', 'equal', 20),
            DownloadGroupMembershipDeletion('g', 'newer', 20),
          ],
        ),
      );
      expect(await store.findMembership('g', 'equal'), isNull);
      expect((await store.findMembership('g', 'newer'))!.addedAtMs, 21);
      expect(await store.findMembership('other', 'equal'), isNotNull);

      await merger.apply(
        const DownloadGroupsSnapshot(
          memberships: [DownloadGroupMembership('g', 'equal', 21)],
          membershipTombstones: [
            DownloadGroupMembershipDeletion('g', 'equal', 10),
          ],
        ),
      );
      expect((await store.findMembership('g', 'equal'))!.addedAtMs, 21);
      expect(await store.membershipDeletedAt('g', 'equal'), 20);
    },
  );

  test(
    'group deletions block stale revival and preserve default fallback order',
    () async {
      await store.putGroup(
        const DownloadGroup(id: 'g', name: 'Group', createdAtMs: 10),
      );
      await store.putMembership('g', 'kept', 11);
      await store.putMembership('g', 'removed', 11);
      const remote = DownloadGroupsSnapshot(
        groups: [DownloadGroup(id: 'g', name: 'Stale', createdAtMs: 20)],
        memberships: [DownloadGroupMembership('g', 'stale', 20)],
        groupTombstones: [DownloadGroupDeletion('g', 20)],
        membershipTombstones: [
          DownloadGroupMembershipDeletion('g', 'removed', 20),
        ],
      );
      await merger.apply(remote);
      await merger.apply(remote);
      expect(await store.findGroup('g'), isNull);
      expect(await store.loadMemberships(groupId: 'g'), isEmpty);
      expect((await store.findMembership('default', 'kept'))!.addedAtMs, 20);
      expect(await store.findMembership('default', 'removed'), isNull);
      expect(await store.findMembership('default', 'stale'), isNull);
    },
  );

  test('replace clears old records and tombstones', () async {
    await store.putGroup(
      const DownloadGroup(id: 'old', name: 'Old', createdAtMs: 1),
    );
    await store.putMembership('old', 'a', 2);
    await store.putGroupTombstone('deleted', 3);
    await store.putMembershipTombstone('old', 'b', 4);
    await merger.apply(
      const DownloadGroupsSnapshot(
        groups: [DownloadGroup(id: 'new', name: 'New', createdAtMs: 1)],
        memberships: [DownloadGroupMembership('new', 'c', 2)],
      ),
      replace: true,
    );
    expect((await store.loadGroups()).single.id, 'new');
    expect((await store.loadMemberships()).single.comicStorageKey, 'c');
    expect(await store.loadGroupTombstones(), isEmpty);
    expect(await store.loadMembershipTombstones(), isEmpty);
  });

  test(
    'replace rolls back writes on failure and publishes only successful state',
    () async {
      final failingStore = _FailingPersistence(database);
      final service = DownloadGroupsService.withPersistence(failingStore);
      addTearDown(service.dispose);
      await service.initialize(['original']);
      final before = jsonDecode(await service.exportJsonString());
      var notifications = 0;
      service.addListener(() => notifications++);
      const remote =
          '{"groups":[{"id":"g","name":"New","createdAtMs":1}],'
          '"memberships":[{"groupId":"g","comicStorageKey":"new","addedAtMs":2}]}';

      failingStore.failWrites = true;
      await expectLater(
        service.importJsonString(remote, replace: true),
        throwsStateError,
      );
      expect(jsonDecode(await service.exportJsonString()), before);
      expect(service.comicKeysForGroup('default'), {'original'});
      expect(notifications, 0);

      failingStore.failWrites = false;
      await service.importJsonString(remote, replace: true);
      expect(notifications, 1);
      expect(service.comicKeysForGroup('g'), {'new'});
      expect(service.comicKeysForGroup('default'), isEmpty);
      expect(service.groups.any((group) => group.isDefault), isTrue);
    },
  );

  test(
    'malformed and absent snapshots do not clear existing data or notify',
    () async {
      final service = DownloadGroupsService.withPersistence(store);
      addTearDown(service.dispose);
      await service.initialize(['original']);
      var notifications = 0;
      service.addListener(() => notifications++);
      final before = jsonDecode(await service.exportJsonString());
      await service.importJsonString(null, replace: true);
      await service.importJsonString('[]', replace: true);
      await expectLater(
        service.importJsonString(
          '{"memberships":[{"groupId":"g","comicStorageKey":"x","addedAtMs":"bad"}]}',
          replace: true,
        ),
        throwsA(isA<TypeError>()),
      );
      expect(jsonDecode(await service.exportJsonString()), before);
      expect(notifications, 0);
    },
  );
}

class _FailingPersistence extends DownloadGroupsPersistence {
  _FailingPersistence(super.database);

  bool failWrites = false;

  @override
  Future<void> putMembership(String groupId, String key, int addedAtMs) async {
    await super.putMembership(groupId, key, addedAtMs);
    if (failWrites) throw StateError('Injected write failure');
  }
}
