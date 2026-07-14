import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/account/source_relogin_coordinator.dart';
import 'package:hazuki/services/source/favorites/source_favorites_capability.dart';
import 'package:hazuki/services/source/models/source_contract_models.dart';
import 'package:hazuki/services/source/runtime/source_runtime_host.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';

void main() {
  test(
    'normalizes folders, merges comics, and preserves parsed source keys',
    () {
      final host = _createHost();
      final parsedSourceKeys = <String>[];
      final capability = _createCapability(
        host,
        parseExploreComics: (comics, {sourceKey = ''}) {
          parsedSourceKeys.add(sourceKey);
          return comics
              .cast<Map>()
              .map(
                (comic) => ExploreComic(
                  id: comic['id']!.toString(),
                  title: comic['title']!.toString(),
                  subTitle: '',
                  cover: '',
                  sourceKey: sourceKey.isEmpty ? 'jm' : sourceKey,
                ),
              )
              .toList();
        },
      );

      final parsed = capability.parseFavoriteComicsForTesting([
        {'id': 'same', 'title': 'Older'},
        {'id': 'same', 'title': 'Newest'},
        {'id': 'other', 'title': 'Other'},
      ], sourceKey: 'copy_manga');
      final merged = SourceFavoritesCapability.mergeFavoriteComics(parsed);

      expect(SourceFavoritesCapability.normalizeFolderId('  '), '0');
      expect(SourceFavoritesCapability.normalizeFolderId(' folder '), 'folder');
      expect(parsedSourceKeys, ['copy_manga']);
      expect(merged.map((comic) => comic.id), ['same', 'other']);
      expect(merged.first.title, 'Newest');
      expect(merged.every((comic) => comic.sourceKey == 'copy_manga'), isTrue);
      host.dispose();
    },
  );

  test(
    'validates requested sources and reports an uninitialized runtime',
    () async {
      final host = _createHost();
      final capability = _createCapability(host);

      expect(
        () => capability.supportFavoriteToggleForSource('missing'),
        throwsA(isA<Exception>()),
      );
      final result = await capability.loadFavoriteFolders();

      expect(result.errorMessage, contains('source_not_initialized'));
      host.dispose();
    },
  );
}

SourceFavoritesCapability _createCapability(
  SourceRuntimeHost host, {
  SourceFavoritesComicParser? parseExploreComics,
}) {
  return SourceFavoritesCapability(
    runtimeHost: host,
    reloginCoordinator: SourceReloginCoordinator(
      loginWithStoredAccount:
          (_, {required account, required password}) async {},
    ),
    parseExploreComics:
        parseExploreComics ??
        (comics, {sourceKey = ''}) => const <ExploreComic>[],
    updateComicDetailsFavoriteState:
        ({required sourceKey, required comicId, required isFavorite}) {},
    notifyCloudFavoritesChanged: () {},
  );
}

SourceRuntimeHost _createHost() {
  return SourceRuntimeHost(
    catalog: const [
      SourceCatalogEntry(key: 'jm', name: 'JM', fileName: 'jm.js'),
      SourceCatalogEntry(
        key: 'copy_manga',
        name: 'CopyManga',
        fileName: 'copy_manga.js',
      ),
    ],
    defaultSourceKey: 'jm',
    secureSessionStorage: MemorySourceSecureSessionStorage(),
    ensureSourceInitialized: (_) async {},
    currentAccountForSource: (_) => null,
    isLoggedForSource: (_) => false,
  );
}
