import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_inappwebview_windows/flutter_inappwebview_windows.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('each environment disposes its own native resource', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final created = <String>[];
    final disposed = <String>[];
    const factory =
        MethodChannel('com.pichillilorenzo/flutter_webview_environment');
    messenger.setMockMethodCallHandler(factory, (call) async {
      if (call.method != 'create') return null;
      final id = (call.arguments as Map)['id'] as String;
      created.add(id);
      messenger.setMockMethodCallHandler(
          MethodChannel('com.pichillilorenzo/flutter_webview_environment_$id'),
          (event) async {
        if (event.method == 'dispose') disposed.add(id);
        return null;
      });
      return true;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(factory, null);
      for (final id in created) {
        messenger.setMockMethodCallHandler(
            MethodChannel(
                'com.pichillilorenzo/flutter_webview_environment_$id'),
            null);
      }
    });
    final first = await WindowsWebViewEnvironment.static().create();
    final second = await WindowsWebViewEnvironment.static().create();
    expect(first.id, isNot(second.id));
    await second.dispose();
    await first.dispose();
    expect(disposed, [second.id, first.id]);
  });
}
