import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/local_favorites/local_favorite_sort.dart';
import 'package:hazuki/features/favorite/state/favorite_page_state.dart';
import 'package:hazuki/models/hazuki_models.dart';

void main() {
  test('local sort choices do not depend on cloud capabilities', () {
    final state = FavoritePageData()..mode = FavoritePageMode.local;
    for (final cloudOrders in <List<String>>[
      [],
      ['custom'],
      ['dd', 'da'],
    ]) {
      final actions = state.buildAppBarActionsState(
        isLogged: false,
        supportFavoriteSortOrder: false,
        supportFavoriteFolderAdd: false,
        favoriteSortOrders: cloudOrders,
      );
      expect(actions.showSort, isTrue);
      expect(actions.sortOrders, [
        'savedNewest',
        'savedOldest',
        'updatedNewest',
      ]);
    }
  });

  test(
    'migrates legacy and custom codes without reinterpreting app strategies',
    () {
      for (final entry in {
        'mr': 'savedNewest',
        'dd': 'savedNewest',
        'da': 'savedOldest',
        'mp': 'updatedNewest',
        '-datetime_updated': 'updatedNewest',
        '-datetime_modifier': 'savedNewest',
        '-datetime_browse': 'savedNewest',
        '': 'savedNewest',
        'unknown': 'savedNewest',
      }.entries) {
        expect(normalizeLocalFavoriteSort(entry.key), entry.value);
      }
      final presentation = {
        'localFavoriteOrders': {
          'custom': 'updatedNewest',
          'savedOldest': 'savedNewest',
        },
      };
      expect(
        normalizeLocalFavoriteSort('custom', presentation: presentation),
        'updatedNewest',
      );
      for (final order in localFavoriteSortOrders) {
        expect(
          normalizeLocalFavoriteSort(order, presentation: presentation),
          order,
        );
      }
    },
  );
}
