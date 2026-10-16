import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/plugins/source_presentation_metadata.dart';

void main() {
  test(
    'historical display rules exclude retired detail fields and operations',
    () {
      expect(
        historicalSourcePresentation({
          'showUploader': true,
          'showCategories': true,
          'showChineseTeam': true,
          'detailTagGroups': ['Genre'],
          'listTagGroups': ['Tags'],
          'showTags': true,
          'showComicStatus': true,
          'enrichMissingTags': true,
          'buttons': [
            {'id': 'checkIn', 'location': 'homeProfile'},
          ],
        }),
        {
          'listTagGroups': ['Tags'],
          'showTags': true,
          'showComicStatus': true,
        },
      );
    },
  );
}
