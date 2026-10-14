import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/shared/source_comic_tags.dart';

void main() {
  test('extracts only plugin-declared tag groups', () {
    const details = ComicDetailsData(
      id: 'comic',
      title: 'Comic',
      subTitle: '',
      cover: '',
      description: '',
      updateTime: '',
      likesCount: '',
      chapters: {},
      tags: {
        '作者': ['Author'],
        '标签': ['Action'],
        '分类': ['Romance'],
      },
      recommend: [],
      isFavorite: false,
      subId: '',
    );

    expect(
      sourceComicDetailTags(details, {
        'listTagGroups': ['标签', '分类'],
      }),
      ['Action', 'Romance'],
    );
    expect(sourceComicDetailTags(details, const {}), isEmpty);
    expect(
      sourceComicDetailTags(details, {
        'listTagGroups': ['作者'],
      }),
      ['Author'],
    );
  });
}
