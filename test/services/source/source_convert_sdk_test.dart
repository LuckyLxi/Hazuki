import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/runtime/source_js_bridge_cookie_capability.dart';
import 'package:hazuki/services/source/runtime/source_runtime_handle.dart';
import 'package:hazuki/services/source/runtime/source_script_engine.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SourceScriptEngine> _createEngine() async {
  final handle = SourceRuntimeHandle(
    sourceKey: 'convert_source',
    secureStorage: MemorySourceSecureSessionStorage(),
    ensureInitialized: (_) async {},
    notifyRuntimeStateChanged: (_) {},
  );
  addTearDown(handle.requestDispose);
  final bridge = SourceJsBridgeCookieCapability(activeHandle: () => handle);
  final engine = SourceScriptEngine(
    timeout: 5000,
    hostPromiseRejectionHandler: (_) {},
  );
  handle.runtime.engine = engine;
  engine.setMessageHandler(
    (dynamic request) => bridge.handleJsMessageForHandle(handle, request),
  );
  await engine.evaluate(await File('assets/init.js').readAsString());
  await engine.evaluate(
    await File('assets/hazuki_plugin_sdk.js').readAsString(),
  );
  return engine;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('hexDecode round-trips with hexEncode and rejects bad input', () async {
    final engine = await _createEngine();
    final result = await engine.evaluate('''
(() => {
  const c = Hazuki.convert;
  const bytes = Array.from(new Uint8Array(c.hexDecode('00ff7A10')));
  const errors = ['abc', 'zz', 1234].map(value => {
    try { c.hexDecode(value); return 'accepted'; } catch (e) { return String(e.message); }
  });
  return {bytes, roundTrip: c.hexEncode(c.hexDecode('00ff7a10')), errors,
    empty: new Uint8Array(c.hexDecode('')).length};
})()
''');
    expect(result['bytes'], [0, 255, 122, 16]);
    expect(result['roundTrip'], '00ff7a10');
    expect(result['errors'], List.filled(3, 'plugin_invalid_hex'));
    expect(result['empty'], 0);
  });

  test('randomBytes and randomUUID use host randomness', () async {
    final engine = await _createEngine();
    final result = await engine.evaluate('''
(() => {
  const c = Hazuki.convert;
  return {length: new Uint8Array(c.randomBytes(24)).length,
    uuids: [c.randomUUID(), c.randomUUID()]};
})()
''');
    expect(result['length'], 24);
    final uuids = (result['uuids'] as List).cast<String>();
    final pattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );
    expect(uuids, everyElement(matches(pattern)));
    expect(uuids.first, isNot(uuids.last));
  });
}
