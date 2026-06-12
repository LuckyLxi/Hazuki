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
}
