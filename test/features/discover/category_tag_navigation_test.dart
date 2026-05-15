import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/discover/support/category_tag_navigation.dart';
import 'package:hazuki/models/hazuki_models.dart';

void main() {
  group('resolveCategoryTagNavigationTarget', () {
    test('opens category tags with matching params', () {
      final target = resolveCategoryTagNavigationTarget(
        const <CategoryTagGroup>[
          CategoryTagGroup(
            name: 'Categories',
            tags: <String>['Ranking', 'Finished'],
            params: <String?>['ranking', 'finished'],
            itemType: 'category',
          ),
        ],
        'Ranking',
      );

      expect(target, isNotNull);
      expect(target!.title, 'Ranking');
      expect(target.viewMoreUrl, 'category:Ranking@ranking');
    });

    test('keeps search tags on the search path', () {
      final target = resolveCategoryTagNavigationTarget(
        const <CategoryTagGroup>[
          CategoryTagGroup(
            name: 'Tags',
            tags: <String>['Action'],
            itemType: 'search',
          ),
        ],
        'Action',
      );

      expect(target, isNull);
    });
  });
}
