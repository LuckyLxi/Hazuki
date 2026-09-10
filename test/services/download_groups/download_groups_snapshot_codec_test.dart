import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/download_groups/download_groups_snapshot_codec.dart';

void main() {
  const codec = DownloadGroupsSnapshotCodec();

  test('round trips all v1 snapshot fields', () {
    final data = {
      'version': 1,
      'groups': [
        {'id': 'g', 'name': 'Group', 'createdAtMs': 10, 'sortOrder': 2},
      ],
      'memberships': [
        {'groupId': 'g', 'comicStorageKey': 'jm::a', 'addedAtMs': 11},
      ],
      'groupTombstones': [
        {'groupId': 'deleted', 'deletedAtMs': 12},
      ],
      'membershipTombstones': [
        {'groupId': 'g', 'comicStorageKey': 'jm::b', 'deletedAtMs': 13},
      ],
    };
    expect(jsonDecode(codec.encode(codec.decode(jsonEncode(data))!)), data);
  });

  test('retains legacy defaults and skips invalid records', () {
    final snapshot = codec.decode(
      jsonEncode({
        'groups': [
          null,
          {'id': '', 'name': 'Ignored'},
          {'id': 'g', 'name': ' Group '},
        ],
        'memberships': [
          false,
          {'groupId': 'g'},
          {'groupId': 'g', 'comicStorageKey': 'a'},
        ],
        'groupTombstones': [
          {'groupId': 'default', 'deletedAtMs': 20},
          {'groupId': 'g', 'deletedAtMs': 0},
          {'groupId': 'deleted', 'deletedAtMs': 20},
        ],
      }),
    )!;
    expect(snapshot.groups.single.name, 'Group');
    expect(snapshot.groups.single.createdAtMs, 0);
    expect(snapshot.groups.single.sortOrder, 0);
    expect(snapshot.memberships.single.comicStorageKey, 'a');
    expect(snapshot.memberships.single.addedAtMs, 0);
    expect(snapshot.groupTombstones.single.groupId, 'deleted');
    expect(snapshot.membershipTombstones, isEmpty);
  });

  test('empty and non-map inputs are no-ops but malformed fields fail', () {
    for (final raw in [null, '', '  ', 'null', '[]', '1']) {
      expect(codec.decode(raw), isNull);
    }
    expect(() => codec.decode('{'), throwsFormatException);
    expect(() => codec.decode('{"groups":{}}'), throwsA(isA<TypeError>()));
    expect(
      () => codec.decode(
        '{"groups":[{"id":"g","name":"G","createdAtMs":"bad"}]}',
      ),
      throwsA(isA<TypeError>()),
    );
  });
}
