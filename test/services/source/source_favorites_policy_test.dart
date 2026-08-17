import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/models/source_meta.dart';
import 'package:hazuki/services/source/favorites/source_favorites_policy.dart';
import 'package:hazuki/services/source/models/source_contract_models.dart';
import 'package:hazuki/services/source/runtime/source_runtime_host.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('uninitialized runtimes report no favorite capabilities', () {
    final host = _createHost('jm');
    final policy = SourceFavoritesPolicy(host);

    expect(policy.favoriteSingleFolderForSingleComic, isFalse);
    expect(policy.supportFavoriteFolderManagement, isFalse);
    expect(policy.supportFavoriteLoadComics, isFalse);
    expect(policy.supportFavoriteToggle, isFalse);
    expect(policy.favoriteSortOrder, 'mr');
    expect(
      () => policy.supportFavoriteToggleForSource('missing'),
      throwsA(isA<Exception>()),
    );
    host.dispose();
  });

  test('persists JM favorite sort order with its fallback', () async {
    final host = await _initializedHost('jm');
    final policy = SourceFavoritesPolicy(host);

    expect(policy.favoriteSortOrders, ['mr', 'mp']);
    expect(policy.favoriteSortOrder, 'mr');
    await policy.setFavoriteSortOrder('mp');
    expect(policy.favoriteSortOrder, 'mp');
    await policy.setFavoriteSortOrder('invalid');
    expect(policy.favoriteSortOrder, 'mr');
    host.dispose();
  });

  test('persists CopyManga favorite sort order with its fallback', () async {
    final host = await _initializedHost('copy_manga');
    final policy = SourceFavoritesPolicy(host);

    expect(policy.favoriteSortOrders, [
      '-datetime_updated',
      '-datetime_modifier',
      '-datetime_browse',
    ]);
    expect(policy.favoriteSortOrder, '-datetime_updated');
    await policy.setFavoriteSortOrder('-datetime_browse');
    expect(policy.favoriteSortOrder, '-datetime_browse');
    await policy.setFavoriteSortOrder('invalid');
    expect(policy.favoriteSortOrder, '-datetime_updated');
    host.dispose();
  });

  test('persists Picacg favorite sort order with its fallback', () async {
    final host = await _initializedHost('picacg');
    final policy = SourceFavoritesPolicy(host);

    expect(policy.favoriteSortOrders, ['dd', 'da']);
    expect(policy.favoriteSortOrder, 'dd');
    await policy.setFavoriteSortOrder('da');
    expect(policy.favoriteSortOrder, 'da');
    await policy.setFavoriteSortOrder('invalid');
    expect(policy.favoriteSortOrder, 'dd');
    host.dispose();
  });
}

Future<SourceRuntimeHost> _initializedHost(String sourceKey) async {
  SharedPreferences.setMockInitialValues(const {});
  final host = _createHost(sourceKey);
  await host.activeHandle.facade.ensurePrefs();
  host.activeHandle.runtime.sourceMeta = SourceMeta(
    name: sourceKey,
    key: sourceKey,
    version: '1.0.0',
    supportsAccount: false,
    settingsDefaults: const {},
  );
  return host;
}

SourceRuntimeHost _createHost(String defaultSourceKey) {
  return SourceRuntimeHost(
    catalog: const [
      SourceCatalogEntry(key: 'jm', name: 'JM', fileName: 'jm.js'),
      SourceCatalogEntry(
        key: 'copy_manga',
        name: 'CopyManga',
        fileName: 'copy_manga.js',
      ),
      SourceCatalogEntry(key: 'picacg', name: 'Picacg', fileName: 'picacg.js'),
    ],
    defaultSourceKey: defaultSourceKey,
    secureSessionStorage: MemorySourceSecureSessionStorage(),
    ensureSourceInitialized: (_) async {},
    currentAccountForSource: (_) => null,
    isLoggedForSource: (_) => false,
  );
}
