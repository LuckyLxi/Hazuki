import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/account/picacg_login_profile_operations.dart';
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
        'results': {'token': ' copy-token ', 'avatar': 'user/cover/avatar.jpg'},
      },
    );

    expect(facade.loadSourceData('copy_manga', 'token'), 'copy-token');
    expect(
      facade.runtime.transientAvatarUrl,
      'https://s3.mangafuna.xyz/user/cover/avatar.jpg',
    );
  });

  test('Picacg adapter extracts token and JWT display name', () async {
    const profile = PicacgLoginProfileOperations();
    final facade = host.activeHandle.facade;
    final payload = base64Url.encode(
      utf8.encode(jsonEncode({'name': 'Picacg User'})),
    );
    final token = 'header.$payload.signature';

    final persisted = await profile.persist(
      facade,
      sourceKey: 'picacg',
      result: {
        'authResponses': [
          {
            'parsedBody': {
              'data': {'token': token},
            },
          },
        ],
      },
    );

    expect(persisted, isTrue);
    expect(facade.loadSourceData('picacg', 'token'), token);
    expect(facade.loadSourceData('picacg', 'display_name'), 'Picacg User');
  });

  test('Picacg adapter rejects responses without an auth token', () async {
    const profile = PicacgLoginProfileOperations();

    expect(
      await profile.persist(
        host.activeHandle.facade,
        sourceKey: 'picacg',
        result: const {'authResponses': []},
      ),
      isFalse,
    );
  });
}
