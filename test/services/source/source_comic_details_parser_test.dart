import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/comic/source_comic_details_parser.dart';
import 'package:hazuki/shared/chapter_title_resolver.dart';

void main() {
  const parser = SourceComicDetailsParser(_translate);

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
