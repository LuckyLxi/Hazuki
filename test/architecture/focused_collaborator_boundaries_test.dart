import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'reader and details do not import the download service implementation',
    () {
      final violations = <String>[];
      for (final feature in ['reader', 'comic_detail']) {
        for (final file in Directory(
          'lib/features/$feature',
        ).listSync(recursive: true).whereType<File>()) {
          if (!file.path.endsWith('.dart')) continue;
          if (file.readAsStringSync().contains('manga_download_service.dart')) {
            violations.add(file.path);
          }
        }
      }
      expect(violations, isEmpty, reason: violations.join('\n'));
    },
  );

  test(
    'recommendation collaborators do not depend on their service facade',
    () {
      for (final file in Directory(
        'lib/services/discover_daily_recommendation',
      ).listSync().whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        expect(
          file.readAsStringSync(),
          isNot(contains('DiscoverDailyRecommendationService')),
          reason: file.path,
        );
        expect(
          file.readAsStringSync(),
          isNot(contains('discover_daily_recommendation_service.dart')),
          reason: file.path,
        );
      }
    },
  );
}
