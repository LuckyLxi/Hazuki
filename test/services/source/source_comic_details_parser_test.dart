import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/models/comic_detail_models.dart';
import 'package:hazuki/services/source/comic/source_comic_details_parser.dart';
import 'package:hazuki/shared/chapter_title_resolver.dart';

void main() {
  test(
    'ordered chapter groups override legacy numeric object keys and retain IDs',
    () {
      const parser = SourceComicDetailsParser(_translate);
      final details = parser.parse(
        map: {
          'chapters': {'2': 'old', '10': 'old'},
          'chapterGroups': [
            {
              'id': 'serial',
              'title': 'Serial',
              'chapters': [
                {'id': '10', 'title': 'First'},
                {'id': '2', 'title': 'Second'},
              ],
            },
            {
              'id': 'other',
              'title': 'Other',
              'chapters': [
                {'id': '1', 'title': 'Alternative'},
              ],
            },
          ],
        },
        fallbackComicId: 'comic',
        sourceKey: 'sample',
      );
      expect(details.chapters.keys, ['10', '2', '1']);
      expect(details.chapterGroups.map((g) => g.id), ['serial', 'other']);
      expect(details.groupForChapter('2')?.id, 'serial');
      expect(
        details.copyWith(isFavorite: true).chapterGroups,
        details.chapterGroups,
      );
    },
  );

  test(
    'duplicate chapter IDs across groups fail instead of replacing chapters',
    () {
      const parser = SourceComicDetailsParser(_translate);
      expect(
        () => parser.parse(
          map: {
            'chapterGroups': [
              {
                'id': 'a',
                'title': 'A',
                'chapters': [
                  {'id': '2', 'title': 'One'},
                ],
              },
              {
                'id': 'b',
                'title': 'B',
                'chapters': [
                  {'id': '2', 'title': 'Two'},
                ],
              },
            ],
          },
          fallbackComicId: 'c',
          sourceKey: 'sample',
        ),
        throwsFormatException,
      );
    },
  );
  const parser = SourceComicDetailsParser(_translate);

  test(
    'header stats preserve plugin text, language maps, order and actions',
    () {
      final details = parser.parse(
        map: {
          'headerStats': [
            {'text': ' Rating 9.8 '},
            {'text': '  '},
            {
              'text': {'zh': '', 'en': ''},
            },
            {
              'text': {'zh': '12点赞', 'en': '12 likes'},
              'action': 'like',
            },
            {'text': 'Weekly', 'action': 'none'},
          ],
        },
        fallbackComicId: 'id',
        sourceKey: 'custom',
      );
      expect(details.headerStats, hasLength(3));
      expect(details.headerStats.first.text, 'custom:Rating 9.8');
      expect(details.headerStats.first.action, ComicHeaderStatAction.none);
      expect(details.headerStats[1].text, {'zh': '12点赞', 'en': '12 likes'});
      expect(details.headerStats[1].action, ComicHeaderStatAction.like);
      expect(details.headerStats.last.text, 'custom:Weekly');
      expect(
        details.copyWith(isLiked: true).headerStats,
        same(details.headerStats),
      );
      expect(() => details.headerStats.clear(), throwsUnsupportedError);
      expect(
        () => (details.headerStats[1].text as Map).clear(),
        throwsUnsupportedError,
      );
    },
  );

  test('legacy counts and tags never synthesize header stats', () {
    final details = parser.parse(
      map: {
        'likesCount': 12,
        'viewsCount': 345,
        'pageCount': 67,
        'tags': {
          'Status': ['Ongoing'],
        },
      },
      fallbackComicId: 'id',
      sourceKey: 'custom',
    );
    expect(details.headerStats, isEmpty);
  });

  test('rejects malformed header stats and unknown actions', () {
    for (final stats in [
      'bad',
      [null],
      [{}],
      [
        {'text': 42},
      ],
      [
        {
          'text': {'en': 42},
        },
      ],
      [
        {'text': 'Short', 'action': 'unknown'},
      ],
    ]) {
      expect(
        () => parser.parse(
          map: {'headerStats': stats},
          fallbackComicId: 'id',
          sourceKey: 'custom',
        ),
        throwsFormatException,
      );
    }
  });

  test('parses arbitrary rows without splitting or inferring tag groups', () {
    final details = parser.parse(
      map: {
        'tags': {
          'Author': ['Legacy'],
        },
        'viewsCount': 42,
        'infoFields': [
          {
            'label': {'zh': '状态', 'en': 'Status'},
            'values': ' 连载中 ',
          },
          {
            'label': 'Original story',
            'values': [' A, B/C ', '', 'D'],
            'action': 'search',
          },
          {
            'label': 'Hidden',
            'values': [' ', ''],
          },
          {
            'label': 'Publisher',
            'values': ['Example'],
            'action': 'copy',
          },
        ],
      },
      fallbackComicId: 'id',
      sourceKey: 'custom',
    );
    expect(details.infoFields, hasLength(3));
    expect(details.infoFields.first.label, {'zh': '状态', 'en': 'Status'});
    expect(details.infoFields.first.values, ['连载中']);
    expect(details.infoFields.first.action, ComicInfoAction.none);
    expect(details.infoFields[1].label, 'custom:Original story');
    expect(details.infoFields[1].values, ['A, B/C', 'D']);
    expect(details.infoFields[1].action, ComicInfoAction.search);
    expect(details.infoFields.last.action, ComicInfoAction.copy);
    expect(details.viewsCount, '42');
    expect(
      details.copyWith(isFavorite: true).infoFields,
      same(details.infoFields),
    );
    expect(details.copyWith(isLiked: true).viewsCount, '42');
    expect(() => details.infoFields.clear(), throwsUnsupportedError);
    expect(
      () => details.infoFields.first.values.clear(),
      throwsUnsupportedError,
    );
  });

  test(
    'missing infoFields does not synthesize old author or uploader rows',
    () {
      final details = parser.parse(
        map: {
          'tags': {
            'Author': ['Legacy'],
          },
          'uploader': 'Legacy uploader',
        },
        fallbackComicId: 'id',
        sourceKey: 'custom',
      );
      expect(details.infoFields, isEmpty);
      expect(details.viewsCount, isEmpty);
    },
  );

  test(
    'rejects malformed plugin rows instead of partially showing bad data',
    () {
      for (final fields in [
        'bad',
        [null],
        [
          {'values': 'Value'},
        ],
        [
          {'label': '', 'values': 'Value'},
        ],
        [
          {
            'label': {'en': 42},
            'values': 'Value',
          },
        ],
        [
          {
            'label': {'en': ' '},
            'values': 'Value',
          },
        ],
        [
          {
            'label': 'Label',
            'values': [42],
          },
        ],
        [
          {'label': 'Label', 'values': 'Value', 'action': 'unknown'},
        ],
      ]) {
        expect(
          () => parser.parse(
            map: {'infoFields': fields},
            fallbackComicId: 'id',
            sourceKey: 'custom',
          ),
          throwsFormatException,
        );
      }
    },
  );

  test('parses and source-scopes a complete comic detail payload', () {
    final details = parser.parse(
      map: {
        'id': ' canonical ',
        'title': 'Title',
        'subtitle': 'Subtitle',
        'cover': 'cover.jpg',
        'description': 'Description',
        'likesCount': 12,
        'uploader': 'Uploader',
        'maxPage': 18,
        'subId': 'sub-id',
        'isFavorite': 1,
        'isLiked': 'true',
        '__chapterEntries': [
          [' ep-1 ', ' Chapter 1 '],
          ['', 'Ignored'],
        ],
        'chapters': {'legacy': 'Legacy chapter'},
        'tags': {
          'genre': ['Action', 2],
          'updated': [' 2026-08-17 '],
          'ignored': 'not-a-list',
        },
        'recommend': [
          {
            'id': ' related ',
            'title': ' Related title ',
            'subtitle': ' Related subtitle ',
            'cover': ' related.jpg ',
          },
          {'id': '', 'title': 'Ignored'},
          'invalid',
        ],
      },
      fallbackComicId: 'fallback',
      sourceKey: 'copy_manga',
    );

    expect(details.id, 'canonical');
    expect(details.subTitle, 'Subtitle');
    expect(details.pageCount, '18');
    expect(details.likesCount, '12');
    expect(details.isFavorite, isTrue);
    expect(details.isLiked, isTrue);
    expect(details.chapters, {'ep-1': 'Chapter 1'});
    expect(details.updateTime, '2026-08-17');
    expect(details.tags, {
      'copy_manga:genre': ['Action', '2'],
    });
    expect(details.recommend, hasLength(1));
    expect(details.recommend.single.id, 'related');
    expect(details.recommend.single.title, 'Related title');
    expect(details.recommend.single.subTitle, 'Related subtitle');
    expect(details.recommend.single.cover, 'related.jpg');
    expect(details.recommend.single.sourceKey, 'copy_manga');
    expect(details.sourceKey, 'copy_manga');
  });

  test('uses legacy chapters and explicit update time when available', () {
    final details = parser.parse(
      map: {
        'chapters': {' ep-2 ': ' Chapter 2 ', '': 'Ignored'},
        'tags': {
          'time': ['tag time'],
        },
        'updateTime': ' explicit time ',
      },
      fallbackComicId: 'fallback',
      sourceKey: 'jm',
    );

    expect(details.id, 'fallback');
    expect(details.chapters, {'ep-2': 'Chapter 2'});
    expect(details.updateTime, 'explicit time');
    expect(details.tags, isEmpty);
  });

  test('provides a default chapter for malformed source collections', () {
    final details = parser.parse(
      map: {
        '__chapterEntries': [
          ['', ''],
          ['id-only'],
        ],
        'chapters': const [],
        'recommend': const {},
      },
      fallbackComicId: 'fallback',
      sourceKey: 'picacg',
    );

    expect(details.chapters, {'fallback': hazukiDefaultChapterTitleToken});
    expect(details.recommend, isEmpty);
    expect(details.updateTime, isEmpty);
  });
}

String _translate(String text, {String sourceKey = ''}) {
  if (text == 'updated' || text == 'time') return text;
  return '$sourceKey:$text';
}
