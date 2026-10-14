import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/plugins/source_presentation_metadata.dart';

void main() {
  test('legacy uploader declarations retain their display contract', () {
    expect(comicDetailPresentation({'showUploader': true}), {
      'showUploader': true,
      'showCategories': true,
      'showChineseTeam': true,
      'detailTagGroups': ['tag', 'tags', '标签'],
    });
    expect(comicDetailPresentation({}), isEmpty);
    expect(comicDetailPresentation({'showUploader': false}), {
      'showUploader': false,
    });
  });

  test('explicit independent fields override legacy defaults', () {
    const presentation = {
      'showUploader': true,
      'showCategories': false,
      'showChineseTeam': false,
      'detailTagGroups': <String>[],
    };
    expect(comicDetailPresentation(presentation), presentation);
    const withoutUploader = {
      'showUploader': false,
      'showCategories': true,
      'showChineseTeam': true,
      'detailTagGroups': ['Genre'],
    };
    expect(comicDetailPresentation(withoutUploader), withoutUploader);
  });

  test(
    'historical metadata preserves new display fields without operations',
    () {
      expect(
        historicalSourcePresentation({
          'showUploader': false,
          'showCategories': true,
          'showChineseTeam': true,
          'detailTagGroups': ['Genre'],
          'listTagGroups': ['Tags'],
          'enrichMissingTags': true,
          'dailyRecommendation': {'searchOrder': 'newest'},
          'buttons': [
            {'id': 'checkIn', 'location': 'homeProfile'},
          ],
        }),
        {
          'showUploader': false,
          'showCategories': true,
          'showChineseTeam': true,
          'detailTagGroups': ['Genre'],
          'listTagGroups': ['Tags'],
        },
      );
    },
  );

  test('old historical metadata gains the same display compatibility', () {
    expect(
      historicalSourcePresentation({'showUploader': true}),
      comicDetailPresentation({'showUploader': true}),
    );
  });
}
