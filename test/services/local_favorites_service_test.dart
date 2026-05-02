import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/local_favorites_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalFavoritesService selected favorite folder persistence', () {
    late LocalFavoritesService service;

    setUp(() {
      SharedPreferences.setMockInitialValues(const {});
      service = LocalFavoritesService.instance;
    });

    test('uses mode-specific defaults when no folder was saved', () async {
      expect(
        await service.loadSelectedFavoriteFolderId(FavoritePageMode.cloud),
        '0',
      );
      expect(
        await service.loadSelectedFavoriteFolderId(FavoritePageMode.local),
        isEmpty,
      );
    });

    test(
      'saves and restores cloud and local folder ids independently',
      () async {
        await service.saveSelectedFavoriteFolderId(
          FavoritePageMode.cloud,
          ' cloud-b ',
        );
        await service.saveSelectedFavoriteFolderId(
          FavoritePageMode.local,
          ' local-b ',
        );

        expect(
          await service.loadSelectedFavoriteFolderId(FavoritePageMode.cloud),
          'cloud-b',
        );
        expect(
          await service.loadSelectedFavoriteFolderId(FavoritePageMode.local),
          'local-b',
        );
      },
    );

    test('normalizes empty cloud ids and clears empty local ids', () async {
      await service.saveSelectedFavoriteFolderId(FavoritePageMode.cloud, '');
      await service.saveSelectedFavoriteFolderId(
        FavoritePageMode.local,
        'local-b',
      );
      await service.saveSelectedFavoriteFolderId(FavoritePageMode.local, '');

      expect(
        await service.loadSelectedFavoriteFolderId(FavoritePageMode.cloud),
        '0',
      );
      expect(
        await service.loadSelectedFavoriteFolderId(FavoritePageMode.local),
        isEmpty,
      );
    });
  });
}
