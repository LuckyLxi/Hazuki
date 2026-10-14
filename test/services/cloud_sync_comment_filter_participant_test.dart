import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/cloud_sync/cloud_sync_comment_filter_participant.dart';
import 'package:hazuki/services/comment_filter/comment_filter_sync_store.dart';
import 'package:hazuki/shared/preferences/hazuki_preference_keys.dart';

class _Store implements CommentFilterSyncStore {
  CommentFilterMergeSnapshot? written;

  @override
  Future<CommentFilterMergeSnapshot> captureMergeSnapshot() async =>
      const CommentFilterMergeSnapshot(keywords: ['local'], updatedAtMs: 100);

  @override
  Future<void> applyMergedKeywords(CommentFilterMergeSnapshot snapshot) async {
    written = snapshot;
  }

  @override
  Future<void> applySyncedPreferences(
    Map<String, Object?> values, {
    bool stringifyUnknown = false,
  }) async =>
      throw StateError('Unexpected preference patch during keyword merge');

  @override
  Future<void> reloadAfterExternalChange() async =>
      throw StateError('Keyword merge must not publish partial settings');
}

void main() {
  final cases = [
    (
      name: 'newer local edit wins',
      localAt: 200,
      remoteAt: 100,
      newerSettings: true,
      expected: ['local'],
      updatedAt: 200,
    ),
    (
      name: 'newer remote edit wins',
      localAt: 100,
      remoteAt: 200,
      newerSettings: false,
      expected: ['remote'],
      updatedAt: 200,
    ),
    (
      name: 'equal timestamps keep local on old settings',
      localAt: 100,
      remoteAt: 100,
      newerSettings: false,
      expected: ['local'],
      updatedAt: 100,
    ),
    (
      name: 'equal timestamps use newer remote settings',
      localAt: 100,
      remoteAt: 100,
      newerSettings: true,
      expected: ['remote'],
      updatedAt: 100,
    ),
    (
      name: 'legacy older settings do not revive deletions',
      localAt: 0,
      remoteAt: 0,
      newerSettings: false,
      expected: ['local'],
      updatedAt: 0,
    ),
    (
      name: 'legacy newer settings merge both lists',
      localAt: 0,
      remoteAt: 0,
      newerSettings: true,
      expected: ['remote', 'local'],
      updatedAt: 0,
    ),
  ];
  for (final scenario in cases) {
    test(scenario.name, () async {
      final store = _Store();
      final participant = CommentFilterSyncParticipant(store);
      await participant.mergeRemote(
        {
          hazukiCommentFilterKeywordsKey: ['remote'],
          hazukiCommentFilterKeywordsUpdatedAtKey: scenario.remoteAt,
        },
        CommentFilterMergeSnapshot(
          keywords: ['local'],
          updatedAtMs: scenario.localAt,
        ),
        remoteSettingsAreNewer: scenario.newerSettings,
      );
      expect(store.written?.keywords, scenario.expected);
      expect(store.written?.updatedAtMs, scenario.updatedAt);
    });
  }

  test('reads the snapshot through the store contract', () async {
    final snapshot = await CommentFilterSyncParticipant(
      _Store(),
    ).captureMergeSnapshot();
    expect(snapshot.keywords, ['local']);
    expect(snapshot.updatedAtMs, 100);
  });

  test('remote deletion preserves its timestamp', () async {
    final store = _Store();
    await CommentFilterSyncParticipant(store).mergeRemote(
      {
        hazukiCommentFilterKeywordsKey: [],
        hazukiCommentFilterKeywordsUpdatedAtKey: 200,
      },
      const CommentFilterMergeSnapshot(keywords: ['deleted'], updatedAtMs: 100),
      remoteSettingsAreNewer: true,
    );
    expect(store.written?.keywords, isEmpty);
    expect(store.written?.updatedAtMs, 200);
  });

  test(
    'legacy merge converts values and removes empty entries and duplicates',
    () async {
      final store = _Store();
      await CommentFilterSyncParticipant(store).mergeRemote(
        {
          hazukiCommentFilterKeywordsKey: ['remote', '', '  ', 'remote', 7],
        },
        const CommentFilterMergeSnapshot(
          keywords: ['local', 'remote'],
          updatedAtMs: 0,
        ),
        remoteSettingsAreNewer: true,
      );
      expect(store.written?.keywords, ['remote', '7', 'local']);
      expect(store.written?.updatedAtMs, 0);
    },
  );

  for (final remote in <Map<String, Object?>>[
    {},
    {hazukiCommentFilterKeywordsKey: null},
    {hazukiCommentFilterKeywordsKey: 'invalid'},
  ]) {
    test('missing or invalid keyword list is ignored: $remote', () async {
      final store = _Store();
      await CommentFilterSyncParticipant(store).mergeRemote(
        remote,
        const CommentFilterMergeSnapshot(keywords: ['local'], updatedAtMs: 100),
        remoteSettingsAreNewer: true,
      );
      expect(store.written, isNull);
    });
  }
}
