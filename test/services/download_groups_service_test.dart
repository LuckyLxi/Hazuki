import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/download_groups_service.dart';
import 'package:hazuki/services/storage/hazuki_database.dart';

void main() {
  late HazukiDatabase database;
  late DownloadGroupsService service;

  setUp(() {
    database = HazukiDatabase.memory();
    service = DownloadGroupsService(database: database);
  });

  tearDown(() async {
    service.dispose();
    await database.close();
  });

  test('new downloaded comics start in the default group', () async {
    await service.initialize(const ['comic-a', 'comic-b']);

    expect(service.groups.single.isDefault, isTrue);
    expect(service.comicKeysForGroup(DownloadGroupsService.defaultGroupId), {
      'comic-a',
      'comic-b',
    });
  });

  test('add keeps memberships while move replaces them', () async {
    await service.initialize(const ['comic-a']);
    final first = await service.createGroup('First');
    final second = await service.createGroup('Second');

    await service.addComicToGroup('comic-a', first.id);
    expect(service.comicKeysForGroup(first.id), contains('comic-a'));
    expect(
      service.comicKeysForGroup(DownloadGroupsService.defaultGroupId),
      contains('comic-a'),
    );

    await service.moveComicToGroup('comic-a', second.id);
    expect(service.comicKeysForGroup(second.id), contains('comic-a'));
    expect(service.comicKeysForGroup(first.id), isNot(contains('comic-a')));
    expect(
      service.comicKeysForGroup(DownloadGroupsService.defaultGroupId),
      isNot(contains('comic-a')),
    );
  });

  test('migrating a legacy comic key preserves its original groups', () async {
    await service.initialize(const ['comic-a']);
    final group = await service.createGroup('First');
    await service.moveComicToGroup('comic-a', group.id);

    await service.reconcileDownloadedComics(
      const ['jm::comic-a'],
      migratedComicKeys: const {'comic-a': 'jm::comic-a'},
    );

    expect(service.comicKeysForGroup(group.id), {'jm::comic-a'});
    expect(
      service.comicKeysForGroup(DownloadGroupsService.defaultGroupId),
      isEmpty,
    );
  });

  test('reconcile preserves groups when local downloads are missing', () async {
    await service.initialize(const ['comic-a']);
    final group = await service.createGroup('First');
    await service.moveComicToGroup('comic-a', group.id);

    await service.reconcileDownloadedComics(const []);
    await service.reconcileDownloadedComics(const ['comic-a']);

    expect(service.comicKeysForGroup(group.id), {'comic-a'});
    expect(
      service.comicKeysForGroup(DownloadGroupsService.defaultGroupId),
      isEmpty,
    );
  });

  test('move can save multiple selected groups at once', () async {
    await service.initialize(const ['comic-a']);
    final first = await service.createGroup('First');
    final second = await service.createGroup('Second');

    await service.moveComicToGroups('comic-a', {first.id, second.id});

    expect(service.comicKeysForGroup(first.id), contains('comic-a'));
    expect(service.comicKeysForGroup(second.id), contains('comic-a'));
    expect(
      service.comicKeysForGroup(DownloadGroupsService.defaultGroupId),
      isNot(contains('comic-a')),
    );
  });

  test('batch add and move update all selected comics together', () async {
    await service.initialize(const ['comic-a', 'comic-b']);
    final first = await service.createGroup('First');
    final second = await service.createGroup('Second');

    await service.addComicsToGroups(
      const ['comic-a', 'comic-b'],
      {first.id, second.id},
    );
    expect(service.comicKeysForGroup(first.id), {'comic-a', 'comic-b'});
    expect(service.comicKeysForGroup(second.id), {'comic-a', 'comic-b'});

    await service.moveComicsToGroups(const ['comic-a', 'comic-b'], {second.id});
    expect(service.comicKeysForGroup(first.id), isEmpty);
    expect(service.comicKeysForGroup(second.id), {'comic-a', 'comic-b'});
  });

  test('removing comics from a group preserves other memberships', () async {
    await service.initialize(const ['comic-a', 'comic-b']);
    final first = await service.createGroup('First');
    final second = await service.createGroup('Second');
    await service.addComicsToGroups(
      const ['comic-a', 'comic-b'],
      {first.id, second.id},
    );

    await service.removeComicsFromGroup(const ['comic-a'], first.id);

    expect(service.comicKeysForGroup(first.id), {'comic-b'});
    expect(service.comicKeysForGroup(second.id), {'comic-a', 'comic-b'});
  });

  test('the last default membership cannot be removed', () async {
    await service.initialize(const ['comic-a']);

    await service.removeComicsFromGroup(const [
      'comic-a',
    ], DownloadGroupsService.defaultGroupId);

    expect(service.comicKeysForGroup(DownloadGroupsService.defaultGroupId), {
      'comic-a',
    });
  });

  test('deleting a group moves its comics to default', () async {
    await service.initialize(const ['comic-a']);
    final group = await service.createGroup('Temporary');
    await service.moveComicToGroup('comic-a', group.id);

    await service.deleteGroup(group.id);

    expect(service.groups.any((item) => item.id == group.id), isFalse);
    expect(
      service.comicKeysForGroup(DownloadGroupsService.defaultGroupId),
      contains('comic-a'),
    );
  });

  test('groups can be renamed and reordered persistently', () async {
    await service.initialize(const []);
    final first = await service.createGroup('First');
    final second = await service.createGroup('Second');

    await service.renameGroup(first.id, 'Renamed');
    await service.reorderGroups([second.id, first.id]);

    expect(service.groups.map((group) => group.name), [
      DownloadGroupsService.defaultGroupName,
      'Second',
      'Renamed',
    ]);

    await service.reload();
    expect(service.groups.map((group) => group.id), [
      DownloadGroupsService.defaultGroupId,
      second.id,
      first.id,
    ]);
  });

  test('webdav snapshot syncs groups and respects deletions', () async {
    await service.initialize(const ['comic-a']);
    final group = await service.createGroup('Synced');
    await service.moveComicToGroup('comic-a', group.id);
    final beforeDelete = await service.exportJsonString();

    final remoteDatabase = HazukiDatabase.memory();
    final remote = DownloadGroupsService(database: remoteDatabase);
    await remote.importJsonString(beforeDelete, replace: true);
    expect(remote.comicKeysForGroup(group.id), contains('comic-a'));

    await service.deleteGroup(group.id);
    await remote.importJsonString(await service.exportJsonString());

    expect(remote.groups.any((item) => item.id == group.id), isFalse);
    expect(
      remote.comicKeysForGroup(DownloadGroupsService.defaultGroupId),
      contains('comic-a'),
    );

    remote.dispose();
    await remoteDatabase.close();
  });

  test(
    'device without local downloads does not sync membership deletion',
    () async {
      await service.initialize(const ['comic-a']);
      final group = await service.createGroup('Synced');
      await service.moveComicToGroup('comic-a', group.id);

      final remoteDatabase = HazukiDatabase.memory();
      final remote = DownloadGroupsService(database: remoteDatabase);
      await remote.importJsonString(
        await service.exportJsonString(),
        replace: true,
      );

      await remote.reconcileDownloadedComics(const []);
      await service.importJsonString(await remote.exportJsonString());

      expect(service.comicKeysForGroup(group.id), contains('comic-a'));
      expect(
        service.comicKeysForGroup(DownloadGroupsService.defaultGroupId),
        isNot(contains('comic-a')),
      );

      remote.dispose();
      await remoteDatabase.close();
    },
  );
}
