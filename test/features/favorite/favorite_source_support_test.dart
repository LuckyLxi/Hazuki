import 'dart:async';
import 'package:hazuki/features/favorite/support/favorite_list_loader.dart';
import 'package:hazuki/features/favorite/support/favorite_local_flow.dart';
import 'package:hazuki/features/favorite/support/favorite_cloud_flow.dart';
import 'package:hazuki/services/local_favorites/local_favorites_contracts.dart';
import 'package:hazuki/services/local_favorites/local_favorites_preferences_store.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hazuki/features/favorite/support/favorite_comic_tag_loader.dart';
import 'package:hazuki/features/favorite/support/favorite_source_policy.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/source_capabilities.dart';

class _Reader extends Mock implements SourceReaderGateway {}

class _Local extends Mock implements LocalFavoritesRepository {}

class _Preferences extends Mock implements LocalFavoritesPreferencesStore {}

class _Source extends Mock implements SourceFavoriteGateway {}

class _Details extends Mock implements ComicDetailsData {}

ExploreComic _comic(
  String id, {
  String source = 'custom_tags',
  List<String> tags = const [],
}) => ExploreComic(
  id: id,
  sourceKey: source,
  title: id,
  subTitle: '',
  cover: '',
  tags: tags,
);

ComicDetailsData _details() {
  final details = _Details();
  when(() => details.tags).thenReturn({
    'tags': [' tag ', 'tag'],
    'categories': ['category'],
    'author': ['ignored'],
  });
  return details;
}

Map<String, dynamic> _presentation(String key) => switch (key.trim()) {
  'custom_tags' => {
    'enrichMissingTags': true,
    'listTagGroups': ['tags', 'categories'],
  },
  'custom_sort' => {
    'refreshCloudFavorites': true,
    'favoriteOrderAliases': {'old': 'new'},
  },
  _ => const {},
};

void main() {
  const policy = FavoriteSourcePolicy(presentationFor: _presentation);

  test('cloud refresh follows plugin metadata for arbitrary identities', () {
    expect(policy.refreshOnCloudFavoritesChanged(' custom_sort '), isTrue);
    for (final source in ['jm', 'picacg', 'copy_manga', '', 'CUSTOM_SORT']) {
      expect(policy.refreshOnCloudFavoritesChanged(source), isFalse);
    }
  });

  test('sort compatibility preserves supported values and legacy mappings', () {
    for (final entry in <(String, List<String>, String)>[
      (' mp ', ['mp', 'mr'], 'mp'),
      ('old', ['other', 'new'], 'new'),
      ('mr', ['custom', '-datetime_modifier'], 'custom'),
      ('-datetime_updated', ['mp'], 'mp'),
      ('unknown', ['mp', 'mr'], 'mp'),
      ('unknown', ['custom'], 'custom'),
      ('unknown', [], ''),
    ]) {
      expect(
        policy.normalizeSortOrder(
          entry.$1,
          allowedOrders: entry.$2,
          sourceKey: 'custom_sort',
        ),
        entry.$3,
      );
    }
  });

  test(
    'fills only plugin-declared missing tags and keeps source-scoped identities',
    () async {
      final reader = _Reader();
      when(
        () =>
            reader.loadComicDetails(any(), sourceKey: any(named: 'sourceKey')),
      ).thenAnswer((_) async => _details());
      final comics = [
        _comic('same'),
        _comic('same', source: 'plain', tags: ['jm tag']),
        _comic('existing', tags: ['original']),
        _comic('other', source: 'plain'),
      ];
      final loaded = <String>[];
      final tags =
          await FavoriteComicTagLoader(
            reader,
            presentationFor: _presentation,
          ).load(
            FavoriteComicsResult.success(comics),
            onTagsLoaded: (comic, tags) => loaded.add(comic.id),
          );
      expect(loaded, ['same']);
      expect(tags[comics[0].scopedId.storageKey], ['tag', 'category']);
      expect(tags[comics[1].scopedId.storageKey], ['jm tag']);
      expect(tags[comics[2].scopedId.storageKey], ['original']);
      expect(comics[0].tags, isEmpty);
      verify(
        () => reader.loadComicDetails('same', sourceKey: 'custom_tags'),
      ).called(1);
      verifyNoMoreInteractions(reader);
    },
  );

  test(
    'failed details do not prevent other comics from being enriched',
    () async {
      final reader = _Reader();
      when(
        () => reader.loadComicDetails('bad', sourceKey: 'custom_tags'),
      ).thenThrow(StateError('unavailable'));
      when(
        () => reader.loadComicDetails('ok', sourceKey: 'custom_tags'),
      ).thenAnswer((_) async => _details());
      final loaded = <String>[];
      final tags =
          await FavoriteComicTagLoader(
            reader,
            presentationFor: _presentation,
          ).load(
            FavoriteComicsResult.success([_comic('bad'), _comic('ok')]),
            onTagsLoaded: (comic, tags) => loaded.add(comic.id),
          );
      expect(loaded, ['ok']);
      expect(tags.length, 1);
    },
  );

  test(
    'empty detail tags, failed pages and missing reader cause no updates',
    () async {
      final reader = _Reader();
      final details = _Details();
      when(() => details.tags).thenReturn({
        'author': ['name'],
      });
      when(
        () =>
            reader.loadComicDetails(any(), sourceKey: any(named: 'sourceKey')),
      ).thenAnswer((_) async => details);
      void unexpectedUpdate(ExploreComic comic, List<String> tags) =>
          fail('Unexpected update');
      expect(
        await FavoriteComicTagLoader(
          reader,
          presentationFor: _presentation,
        ).load(
          FavoriteComicsResult.success([_comic('empty')]),
          onTagsLoaded: unexpectedUpdate,
        ),
        isEmpty,
      );
      verify(
        () => reader.loadComicDetails('empty', sourceKey: 'custom_tags'),
      ).called(1);
      expect(
        await FavoriteComicTagLoader(
          reader,
          presentationFor: _presentation,
        ).load(
          const FavoriteComicsResult.error('failed'),
          onTagsLoaded: unexpectedUpdate,
        ),
        isEmpty,
      );
      expect(
        await const FavoriteComicTagLoader(null).load(
          FavoriteComicsResult.success([_comic('missing')]),
          onTagsLoaded: unexpectedUpdate,
        ),
        isEmpty,
      );
      verifyNoMoreInteractions(reader);
    },
  );

  test(
    'stale requests stop before subsequent batches and perform no updates',
    () async {
      final reader = _Reader();
      final pending = <Completer<ComicDetailsData>>[];
      when(
        () =>
            reader.loadComicDetails(any(), sourceKey: any(named: 'sourceKey')),
      ).thenAnswer((_) {
        final request = Completer<ComicDetailsData>();
        pending.add(request);
        return request.future;
      });
      var current = true;
      final future =
          FavoriteComicTagLoader(reader, presentationFor: _presentation).load(
            FavoriteComicsResult.success(
              List.generate(5, (index) => _comic('$index')),
            ),
            isCurrent: () => current,
            onTagsLoaded: (_, _) => fail('stale request updated tags'),
          );
      expect(pending.length, 4);
      current = false;
      for (final request in pending) {
        request.complete(_details());
      }
      expect(await future, isEmpty);
      expect(pending.length, 4);
    },
  );

  test(
    'local loader keeps the request source while using app sorting',
    () async {
      final local = _Local();
      when(
        () => local.loadFavoriteComics(
          page: 1,
          folderId: 'folder',
          sourceKey: 'custom_sort',
          sortOrder: 'updatedNewest',
        ),
      ).thenAnswer((_) async => const FavoriteComicsResult.success([]));
      final loader = FavoriteListLoader(
        cloud: FavoriteCloudFlow(_Source()),
        local: FavoriteLocalFlow(
          repository: local,
          preferences: _Preferences(),
        ),
      );
      await loader.load(
        request: loader.capture(
          sourceKey: 'custom_sort',
          mode: FavoritePageMode.local,
        ),
        page: 1,
        folderId: 'folder',
        sortOrder: 'updatedNewest',
        timeoutMessage: '',
      );
      verify(
        () => local.loadFavoriteComics(
          page: 1,
          folderId: 'folder',
          sourceKey: 'custom_sort',
          sortOrder: 'updatedNewest',
        ),
      ).called(1);
      loader.dispose();
    },
  );

  test('detail requests run in batches of at most four', () async {
    final reader = _Reader();
    final pending = <Completer<ComicDetailsData>>[];
    when(
      () => reader.loadComicDetails(any(), sourceKey: any(named: 'sourceKey')),
    ).thenAnswer((_) {
      final completer = Completer<ComicDetailsData>();
      pending.add(completer);
      return completer.future;
    });
    final future =
        FavoriteComicTagLoader(reader, presentationFor: _presentation).load(
          FavoriteComicsResult.success(
            List.generate(5, (index) => _comic('$index')),
          ),
          onTagsLoaded: (_, _) {},
        );
    expect(pending.length, 4);
    for (final request in pending.take(3)) {
      request.complete(_details());
    }
    await Future<void>.delayed(Duration.zero);
    expect(pending.length, 4);
    pending[3].complete(_details());
    await Future<void>.delayed(Duration.zero);
    expect(pending.length, 5);
    pending[4].complete(_details());
    expect((await future).length, 5);
  });
}
