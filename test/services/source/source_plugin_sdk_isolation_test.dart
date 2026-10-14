import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/runtime/source_js_bridge_cookie_capability.dart';
import 'package:hazuki/services/source/runtime/source_runtime_handle.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'SDK isolates private data, settings and ambiguous secret names',
    () async {
      final storage = MemorySourceSecureSessionStorage();
      SourceRuntimeHandle create(String id) => SourceRuntimeHandle(
        sourceKey: id,
        secureStorage: storage,
        ensureInitialized: (_) async {},
        notifyRuntimeStateChanged: (_) {},
      );
      final first = create('a');
      final second = create('a_b');
      addTearDown(first.requestDispose);
      addTearDown(second.requestDispose);
      await first.session.ensurePrefs();
      await second.session.ensurePrefs();
      final bridge = SourceJsBridgeCookieCapability(activeHandle: () => first);
      dynamic send(SourceRuntimeHandle handle, Map<String, dynamic> message) =>
          bridge.handleJsMessageForHandle(handle, message);

      await send(first, {
        'method': 'secret_set',
        'secret_key': 'b_c',
        'value': 'first secret',
      });
      await send(second, {
        'method': 'secret_set',
        'secret_key': 'c',
        'value': 'second secret',
      });
      expect(
        await send(first, {'method': 'secret_get', 'secret_key': 'b_c'}),
        'first secret',
      );
      expect(
        await send(second, {'method': 'secret_get', 'secret_key': 'c'}),
        'second secret',
      );
      await send(first, {
        'method': 'save_data',
        'key': 'a',
        'data_key': 'shared_name',
        'data': 'private data',
      });
      expect(
        send(second, {
          'method': 'load_data',
          'key': 'a_b',
          'data_key': 'shared_name',
        }),
        isNull,
      );
      expect(
        () => send(second, {
          'method': 'load_data',
          'key': 'a',
          'data_key': 'shared_name',
        }),
        throwsA(isA<StateError>()),
      );
      await send(first, {
        'method': 'save_setting',
        'key': 'a',
        'setting_key': 'quality',
        'value': 'high',
      });
      expect(
        send(second, {
          'method': 'load_setting',
          'key': 'a_b',
          'setting_key': 'quality',
        }),
        isNull,
      );
      expect(
        () => send(first, {'method': 'plugin_resource', 'path': '../secret'}),
        throwsUnsupportedError,
      );
      first.requestDispose();
      expect(
        () => send(first, {'method': 'secret_get', 'secret_key': 'b_c'}),
        throwsStateError,
      );
    },
  );
}
