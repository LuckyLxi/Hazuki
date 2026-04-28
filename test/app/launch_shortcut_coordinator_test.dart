import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/app/launch_shortcut_bridge.dart';
import 'package:hazuki/app/launch_shortcut_coordinator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('initial search action invokes handler once', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final source = _FakeLaunchShortcutActionSource(
      initialAction: HazukiLaunchShortcutAction.search,
    );
    final handler = _RecordingLaunchShortcutHandler();
    final coordinator = _buildCoordinator(navigatorKey, source, handler);

    await tester.pumpWidget(_TestApp(navigatorKey: navigatorKey));

    coordinator.initialize();
    await tester.pumpAndSettle();

    expect(handler.actions, [HazukiLaunchShortcutAction.search]);

    coordinator.dispose();
  });

  testWidgets('stream search action invokes handler once', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final source = _FakeLaunchShortcutActionSource();
    final handler = _RecordingLaunchShortcutHandler();
    final coordinator = _buildCoordinator(navigatorKey, source, handler);

    await tester.pumpWidget(_TestApp(navigatorKey: navigatorKey));
    coordinator.initialize();
    await tester.pump();

    source.add(HazukiLaunchShortcutAction.search);
    await tester.pumpAndSettle();

    expect(handler.actions, [HazukiLaunchShortcutAction.search]);

    coordinator.dispose();
  });

  testWidgets('initial action errors are ignored', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final source = _FakeLaunchShortcutActionSource(throwInitialAction: true);
    final handler = _RecordingLaunchShortcutHandler();
    final coordinator = _buildCoordinator(navigatorKey, source, handler);

    await tester.pumpWidget(_TestApp(navigatorKey: navigatorKey));

    coordinator.initialize();
    await tester.pumpAndSettle();

    expect(handler.actions, isEmpty);

    coordinator.dispose();
  });

  testWidgets('stream errors are ignored', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final source = _FakeLaunchShortcutActionSource();
    final handler = _RecordingLaunchShortcutHandler();
    final coordinator = _buildCoordinator(navigatorKey, source, handler);

    await tester.pumpWidget(_TestApp(navigatorKey: navigatorKey));
    coordinator.initialize();
    await tester.pump();

    source.addError(Exception('shortcut stream failed'));
    await tester.pumpAndSettle();

    expect(handler.actions, isEmpty);

    coordinator.dispose();
  });

  testWidgets('initialize is idempotent', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final source = _FakeLaunchShortcutActionSource(
      initialAction: HazukiLaunchShortcutAction.search,
    );
    final handler = _RecordingLaunchShortcutHandler();
    final coordinator = _buildCoordinator(navigatorKey, source, handler);

    await tester.pumpWidget(_TestApp(navigatorKey: navigatorKey));

    coordinator.initialize();
    coordinator.initialize();
    await tester.pumpAndSettle();

    expect(handler.actions, [HazukiLaunchShortcutAction.search]);
    expect(source.initialActionCallCount, 1);
    expect(source.listenCount, 1);

    coordinator.dispose();
  });

  testWidgets('duplicate actions are ignored while handler is running', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final source = _FakeLaunchShortcutActionSource();
    final pendingHandler = Completer<void>();
    final handler = _RecordingLaunchShortcutHandler(
      onAction: (_) => pendingHandler.future,
    );
    final coordinator = _buildCoordinator(navigatorKey, source, handler);

    await tester.pumpWidget(_TestApp(navigatorKey: navigatorKey));
    coordinator.initialize();
    await tester.pump();

    source.add(HazukiLaunchShortcutAction.search);
    source.add(HazukiLaunchShortcutAction.search);
    await tester.pump();

    expect(handler.actions, [HazukiLaunchShortcutAction.search]);

    pendingHandler.complete();
    await tester.pumpAndSettle();

    source.add(HazukiLaunchShortcutAction.search);
    await tester.pumpAndSettle();

    expect(handler.actions, [
      HazukiLaunchShortcutAction.search,
      HazukiLaunchShortcutAction.search,
    ]);

    coordinator.dispose();
  });

  testWidgets('handler errors do not leave coordinator busy', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final source = _FakeLaunchShortcutActionSource();
    var shouldThrow = true;
    final handler = _RecordingLaunchShortcutHandler(
      onAction: (_) async {
        if (shouldThrow) {
          shouldThrow = false;
          throw Exception('shortcut handler failed');
        }
      },
    );
    final coordinator = _buildCoordinator(navigatorKey, source, handler);

    await tester.pumpWidget(_TestApp(navigatorKey: navigatorKey));
    coordinator.initialize();
    await tester.pump();

    source.add(HazukiLaunchShortcutAction.search);
    await tester.pumpAndSettle();
    source.add(HazukiLaunchShortcutAction.search);
    await tester.pumpAndSettle();

    expect(handler.actions, [
      HazukiLaunchShortcutAction.search,
      HazukiLaunchShortcutAction.search,
    ]);

    coordinator.dispose();
  });
}

HazukiLaunchShortcutCoordinator _buildCoordinator(
  GlobalKey<NavigatorState> navigatorKey,
  HazukiLaunchShortcutActionSource source,
  _RecordingLaunchShortcutHandler handler,
) {
  return HazukiLaunchShortcutCoordinator(
    navigatorKey: navigatorKey,
    actionSource: source,
    isMounted: () => true,
    handleAction: handler.call,
  );
}

class _RecordingLaunchShortcutHandler {
  _RecordingLaunchShortcutHandler({this.onAction});

  final Future<void> Function(HazukiLaunchShortcutAction action)? onAction;
  final List<HazukiLaunchShortcutAction> actions = [];

  Future<void> call(HazukiLaunchShortcutAction action) async {
    actions.add(action);
    await onAction?.call(action);
  }
}

class _FakeLaunchShortcutActionSource
    implements HazukiLaunchShortcutActionSource {
  _FakeLaunchShortcutActionSource({
    this.initialAction,
    this.throwInitialAction = false,
  }) {
    _controller = StreamController<HazukiLaunchShortcutAction>.broadcast(
      onListen: () {
        listenCount++;
      },
    );
  }

  final HazukiLaunchShortcutAction? initialAction;
  final bool throwInitialAction;
  late final StreamController<HazukiLaunchShortcutAction> _controller;
  int initialActionCallCount = 0;
  int listenCount = 0;

  @override
  Stream<HazukiLaunchShortcutAction> get actions => _controller.stream;

  @override
  Future<HazukiLaunchShortcutAction?> getInitialAction() async {
    initialActionCallCount++;
    if (throwInitialAction) {
      throw Exception('initial shortcut failed');
    }
    return initialAction;
  }

  void add(HazukiLaunchShortcutAction action) {
    _controller.add(action);
  }

  void addError(Object error) {
    _controller.addError(error);
  }
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.navigatorKey});

  final GlobalKey<NavigatorState> navigatorKey;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: SizedBox.shrink()),
    );
  }
}
