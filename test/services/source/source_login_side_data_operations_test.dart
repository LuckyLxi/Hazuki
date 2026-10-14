import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/account/source_login_side_data_operations.dart';
import 'package:hazuki/services/source/models/source_contract_models.dart';
import 'package:hazuki/services/source/runtime/source_runtime_host.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SourceRuntimeHost host;

  setUp(() async {
    SharedPreferences.setMockInitialValues(const {});
    host = SourceRuntimeHost(
      catalog: const [
        SourceCatalogEntry(
          key: 'jm',
          name: 'JMComic',
          fileName: 'jm.js',
          directUrls: [],
        ),
      ],
      defaultSourceKey: 'jm',
      secureSessionStorage: MemorySourceSecureSessionStorage(),
      ensureSourceInitialized: (_) async {},
      currentAccountForSource: (_) => null,
      isLoggedForSource: (_) => false,
    );
    await host.activeHandle.facade.ensurePrefs();
    addTearDown(host.dispose);
  });

  test('persists common CopyManga token and normalized avatar', () async {
    final sideData = SourceLoginSideDataOperations(runtimeHost: host);
    final facade = host.activeHandle.facade;

    await sideData.persistLoginSideData(
      facade,
      sourceKey: 'copy_manga',
      result: {
        'token': 'copy-token',
        'avatarUrl': 'https://s3.mangafuna.xyz/user/cover/avatar.jpg',
      },
    );

    expect(facade.loadSourceData('copy_manga', 'token'), 'copy-token');
    expect(
      facade.runtime.transientAvatarUrl,
      'https://s3.mangafuna.xyz/user/cover/avatar.jpg',
    );
  });

  test(
    'persists plugin-normalized profile without site-specific parsing',
    () async {
      final sideData = SourceLoginSideDataOperations(runtimeHost: host);
      final facade = host.activeHandle.facade;
      await sideData.persistLoginSideData(
        facade,
        sourceKey: 'picacg',
        result: {
          'token': 'pica-token',
          'displayName': 'Picacg User',
          'avatarUrl': 'https://images.example/static/avatar.jpg',
        },
      );
      expect(facade.loadSourceData('picacg', 'token'), 'pica-token');
      expect(facade.loadSourceData('picacg', 'display_name'), 'Picacg User');
      expect(
        facade.loadSourceData('picacg', 'avatar_url'),
        'https://images.example/static/avatar.jpg',
      );
    },
  );

  test(
    'ignores non-profile results without changing stored credentials',
    () async {
      final sideData = SourceLoginSideDataOperations(runtimeHost: host);
      final facade = host.activeHandle.facade;
      await facade.saveSourceData('picacg', 'token', 'previous-token');
      await sideData.persistLoginSideData(
        facade,
        sourceKey: 'picacg',
        result: null,
      );
      expect(facade.loadSourceData('picacg', 'token'), 'previous-token');
    },
  );
}
