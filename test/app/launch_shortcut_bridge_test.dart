import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/app/launch_shortcut_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(HazukiLaunchShortcutProtocol.methodChannelName);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getInitialAction parses search action from method channel', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(
            call.method,
            HazukiLaunchShortcutProtocol.getInitialLaunchActionMethod,
          );
          return HazukiLaunchShortcutProtocol.searchAction;
        });

    final bridge = HazukiLaunchShortcutBridge(supportsLaunchShortcuts: true);

    expect(await bridge.getInitialAction(), HazukiLaunchShortcutAction.search);
  });

  test('getInitialAction ignores unknown and null actions', () async {
    Object? response = 'unknown';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => response);

    final bridge = HazukiLaunchShortcutBridge(supportsLaunchShortcuts: true);

    expect(await bridge.getInitialAction(), isNull);

    response = null;
    expect(await bridge.getInitialAction(), isNull);
  });

  test('getInitialAction returns null when channel is unavailable', () async {
    final bridge = HazukiLaunchShortcutBridge(supportsLaunchShortcuts: true);

    expect(await bridge.getInitialAction(), isNull);
  });

  test('getInitialAction returns null on platform exception', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          throw PlatformException(code: 'launch_shortcut_failed');
        });

    final bridge = HazukiLaunchShortcutBridge(supportsLaunchShortcuts: true);

    expect(await bridge.getInitialAction(), isNull);
  });

  test(
    'unsupported platforms expose no initial action or stream events',
    () async {
      final bridge = HazukiLaunchShortcutBridge(supportsLaunchShortcuts: false);

      expect(await bridge.getInitialAction(), isNull);
      expect(bridge.actions, emitsDone);
    },
  );
}
