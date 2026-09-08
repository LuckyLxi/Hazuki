import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hazuki/features/favorite/support/favorite_comic_tag_loader.dart';
import 'package:hazuki/features/favorite/support/favorite_source_policy.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/source_capabilities.dart';

class _Reader extends Mock implements SourceReaderGateway {}

class _Details extends Mock implements ComicDetailsData {}

ExploreComic _comic(
  String id, {
  String source = 'picacg',
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

void main() {
  const policy = FavoriteSourcePolicy();

  test('only CopyManga cloud changes trigger a refresh', () {
    expect(policy.refreshOnCloudFavoritesChanged(' copy_manga '), isTrue);
    for (final source in ['jm', 'picacg', '', 'COPY_MANGA']) {
      expect(policy.refreshOnCloudFavoritesChanged(source), isFalse);
    }
  });

  test('sort compatibility preserves supported values and legacy mappings', () {
    for (final entry in <(String, List<String>, String)>[
      (' mp ', ['mp', 'mr'], 'mp'),
      ('mp', ['-datetime_updated'], '-datetime_updated'),
      ('mr', ['-datetime_modifier'], '-datetime_modifier'),
      ('-datetime_updated', ['mp'], 'mp'),
      ('unknown', ['mp', 'mr'], 'mr'),
      ('unknown', ['custom'], 'custom'),
      ('unknown', [], 'mr'),
    ]) {
      expect(
        policy.normalizeSortOrder(entry.$1, allowedOrders: entry.$2),
        entry.$3,
      );
    }
  });

  test(
    'fills only missing Picacg tags and keeps source-scoped identities',
    () async {
      final reader = _Reader();
      when(
        () =>
            reader.loadComicDetails(any(), sourceKey: any(named: 'sourceKey')),
      ).thenAnswer((_) async => _details());
      final comics = [
        _comic('same'),
        _comic('same', source: 'jm', tags: ['jm tag']),
        _comic('existing', tags: ['original']),
        _comic('other', source: 'jm'),
      ];
      final loaded = <String>[];
      final tags = await FavoriteComicTagLoader(reader).load(
        FavoriteComicsResult.success(comics),
        onTagsLoaded: (comic, tags) => loaded.add(comic.id),
      );
      expect(loaded, ['same']);
      expect(tags[comics[0].scopedId.storageKey], ['tag', 'category']);
      expect(tags[comics[1].scopedId.storageKey], ['jm tag']);
      expect(tags[comics[2].scopedId.storageKey], ['original']);
      expect(comics[0].tags, isEmpty);
      verify(
        () => reader.loadComicDetails('same', sourceKey: 'picacg'),
      ).called(1);
      verifyNoMoreInteractions(reader);
    },
  );

  test(
    'failed details do not prevent other comics from being enriched',
    () async {
      final reader = _Reader();
      when(
        () => reader.loadComicDetails('bad', sourceKey: 'picacg'),
      ).thenThrow(StateError('unavailable'));
      when(
        () => reader.loadComicDetails('ok', sourceKey: 'picacg'),
      ).thenAnswer((_) async => _details());
      final loaded = <String>[];
      final tags = await FavoriteComicTagLoader(reader).load(
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
        await FavoriteComicTagLoader(reader).load(
          FavoriteComicsResult.success([_comic('empty')]),
          onTagsLoaded: unexpectedUpdate,
        ),
        isEmpty,
      );
      verify(
        () => reader.loadComicDetails('empty', sourceKey: 'picacg'),
      ).called(1);
      expect(
        await FavoriteComicTagLoader(reader).load(
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
    final future = FavoriteComicTagLoader(reader).load(
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
