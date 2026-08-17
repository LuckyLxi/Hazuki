import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/account/source_relogin_coordinator.dart';
import 'package:hazuki/services/source/favorites/source_favorite_comics_loader.dart';
import 'package:hazuki/services/source/favorites/source_favorites_response_parser.dart';
import 'package:hazuki/services/source/models/source_contract_models.dart';
import 'package:hazuki/services/source/runtime/source_runtime_host.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';

void main() {
  test('reports an uninitialized active source as a result error', () async {
    final host = SourceRuntimeHost(
      catalog: const [
        SourceCatalogEntry(key: 'jm', name: 'JM', fileName: 'jm.js'),
      ],
      defaultSourceKey: 'jm',
      secureSessionStorage: MemorySourceSecureSessionStorage(),
      ensureSourceInitialized: (_) async {},
      currentAccountForSource: (_) => null,
      isLoggedForSource: (_) => false,
    );
    final loader = SourceFavoriteComicsLoader(
      runtimeHost: host,
      reloginCoordinator: SourceReloginCoordinator(
        loginWithStoredAccount:
            (_, {required account, required password}) async {},
      ),
      responseParser: SourceFavoritesResponseParser(
        (comics, {sourceKey = ''}) => const <ExploreComic>[],
      ),
    );

    final result = await loader.load(page: 1, folderId: '0');

    expect(result.comics, isEmpty);
    expect(result.maxPage, isNull);
    expect(result.errorMessage, contains('source_not_initialized'));
    host.dispose();
  });
}
