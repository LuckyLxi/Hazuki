import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/models/source_contract_models.dart';
import 'package:hazuki/services/source/runtime/source_runtime_host.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const catalog = [
    SourceCatalogEntry(key: 'jm', name: 'JM', fileName: 'jm.js'),
    SourceCatalogEntry(
      key: 'copy_manga',
      name: 'CopyManga',
      fileName: 'copy_manga.js',
    ),
    SourceCatalogEntry(key: 'picacg', name: 'Picacg', fileName: 'picacg.js'),
  ];

  test(
    'switches sources, disposes the replaced handle, and notifies',
    () async {
      SharedPreferences.setMockInitialValues(const {});
      final host = _createHost(catalog);
      final initial = host.activeHandle;
      var notifications = 0;
      host.addListener(() => notifications++);

      await host.activateSource('copy_manga');

      expect(host.activeSourceKey, 'copy_manga');
      expect(initial.isDisposed, isTrue);
      expect(notifications, 1);
      expect(host.runtimeRegistry.activeSourceKey, 'copy_manga');
      host.dispose();
    },
  );

  test('repairs an invalid persisted source with the default source', () async {
    SharedPreferences.setMockInitialValues({'active_source_key_v1': 'removed'});
    final host = _createHost(catalog);

    await host.loadActiveSourcePreference();

    final prefs = await SharedPreferences.getInstance();
    expect(host.activeSourceKey, 'jm');
    expect(prefs.getString('active_source_key_v1'), 'jm');
    host.dispose();
  });

  test('serializes concurrent source switches in request order', () async {
    SharedPreferences.setMockInitialValues(const {});
    final host = _createHost(catalog);

    await Future.wait([
      host.activateSource('copy_manga'),
      host.activateSource('picacg'),
    ]);

    expect(host.activeSourceKey, 'picacg');
    host.dispose();
  });

  test('rejects an unknown source before creating a handle', () {
    final host = _createHost(catalog);

    expect(() => host.handleFor('unknown'), throwsA(isA<Exception>()));
    host.dispose();
  });
}

SourceRuntimeHost _createHost(List<SourceCatalogEntry> catalog) {
  return SourceRuntimeHost(
    catalog: catalog,
    defaultSourceKey: 'jm',
    secureSessionStorage: MemorySourceSecureSessionStorage(),
    ensureSourceInitialized: (_) async {},
    currentAccountForSource: (_) => null,
    isLoggedForSource: (_) => false,
  );
}
