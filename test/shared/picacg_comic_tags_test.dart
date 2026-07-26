import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/shared/picacg_comic_tags.dart';

void main() {
  test('extracts localized Picacg tag and category values', () {
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

    expect(picacgComicDetailTags(details), ['Action', 'Romance']);
  });
}
