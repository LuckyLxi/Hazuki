import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/app/service_locator.dart';
import 'package:hazuki/services/cloud_sync/cloud_sync_config_store.dart';
import 'package:hazuki/services/cloud_sync/cloud_sync_snapshot_codec.dart';
import 'package:hazuki/services/download_groups_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_service_locator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(const {});
    await ensureTestServiceLocator();
  });

  test('webdav settings snapshot includes download group metadata', () async {
    final groups = sl<DownloadGroupsService>();
    await groups.initialize(const ['comic-a']);
    final group = await groups.createGroup('Synced group');
    await groups.moveComicToGroup('comic-a', group.id);

    final snapshot = await CloudSyncSnapshotCodec(
      configStore: CloudSyncConfigStore(),
    ).buildLocalSnapshotFiles();
    final settings = jsonDecode(snapshot.settings) as Map<String, dynamic>;
    final data = settings['data'] as Map<String, dynamic>;
    final groupSnapshot =
        jsonDecode(data[CloudSyncConfigStore.downloadGroupsKey] as String)
            as Map<String, dynamic>;

    expect(
      (groupSnapshot['groups'] as List).where(
        (item) => (item as Map)['name'] == 'Synced group',
      ),
      isNotEmpty,
    );
    expect(
      (groupSnapshot['memberships'] as List).where(
        (item) =>
            (item as Map)['groupId'] == group.id &&
            item['comicStorageKey'] == 'comic-a',
      ),
      isNotEmpty,
    );
  });
}
