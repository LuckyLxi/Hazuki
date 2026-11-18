import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/settings/state/source_plugins_controller.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:mocktail/mocktail.dart';

class _Gateway extends Mock implements SourcePluginGateway {}

InstalledSourcePlugin _plugin(String id) => InstalledSourcePlugin(
  manifest: SourcePluginManifest(
    id: id,
    name: id,
    version: '1.0.0',
    apiVersion: 1,
    entry: 'main.js',
  ),
  directory: id,
);

void main() {
  late _Gateway gateway;
  late SourcePluginsController controller;

  setUp(() {
    gateway = _Gateway();
    controller = SourcePluginsController(gateway);
  });

  test(
    'different installs run concurrently and duplicate/global work waits',
    () async {
      final first = Completer<void>();
      final second = Completer<void>();
      final a = controller.run(() => first.future, pluginId: 'a');
      final b = controller.run(() => second.future, pluginId: 'b');
      var blockedCalls = 0;
      await controller.run(() async {
        blockedCalls++;
      }, pluginId: 'a');
      await controller.run(() async {
        blockedCalls++;
      });
      expect(blockedCalls, 0);
      expect(controller.isInstalling('a'), isTrue);
      expect(controller.isInstalling('b'), isTrue);
      second.complete();
      await b;
      expect(controller.isInstalling('b'), isFalse);
      expect(controller.hasOperations, isTrue);
      first.complete();
      await a;
      expect(controller.hasOperations, isFalse);
      controller.dispose();
    },
  );

  test(
    'global work blocks installs and enabled changes until completion',
    () async {
      final pending = Completer<void>();
      final operation = controller.run(
        () => pending.future,
        page: PluginOperationPage.available,
      );
      var installCalls = 0;
      await controller.run(() async {
        installCalls++;
      }, pluginId: 'a');
      await controller.setEnabled('a', false);
      expect(controller.busyPage, PluginOperationPage.available);
      expect(installCalls, 0);
      verifyNever(() => gateway.setEnabled(any(), any()));
      pending.complete();
      await operation;
      expect(controller.busyPage, isNull);
      controller.dispose();
    },
  );

  test('failed installs release their slot and allow retry', () async {
    await expectLater(
      controller.run(() async {
        throw StateError('failed');
      }, pluginId: 'a'),
      throwsStateError,
    );
    expect(controller.hasOperations, isFalse);
    var retried = false;
    await controller.run(() async {
      retried = true;
    }, pluginId: 'a');
    expect(retried, isTrue);
    controller.dispose();
  });

  test(
    'enabled state is optimistic, deduplicated and restored on failure',
    () async {
      final plugin = _plugin('a');
      final pending = Completer<void>();
      when(
        () => gateway.setEnabled('a', !plugin.enabled),
      ).thenAnswer((_) => pending.future);
      final operation = controller.setEnabled('a', !plugin.enabled);
      expect(controller.enabledFor(plugin), !plugin.enabled);
      await controller.setEnabled('a', plugin.enabled);
      final failed = expectLater(operation, throwsStateError);
      pending.completeError(StateError('failed'));
      await failed;
      expect(controller.enabledFor(plugin), plugin.enabled);
      expect(controller.isChangingEnabled('a'), isFalse);
      verify(() => gateway.setEnabled('a', !plugin.enabled)).called(1);
      controller.dispose();
    },
  );

  test(
    'sorting appends new plugins and rolls back to the gateway on failure',
    () async {
      var installed = [_plugin('a'), _plugin('b')];
      when(() => gateway.installed).thenAnswer((_) => installed);
      final pending = Completer<void>();
      when(() => gateway.reorder(any())).thenAnswer((_) => pending.future);
      controller.setSorting(true);
      final operation = controller.movePlugin(0, 1);
      installed = [...installed, _plugin('c')];
      expect(controller.sortedInstalled.map((p) => p.manifest.id), [
        'b',
        'a',
        'c',
      ]);
      final failed = expectLater(operation, throwsStateError);
      pending.completeError(StateError('failed'));
      await failed;
      expect(controller.sortedInstalled.map((p) => p.manifest.id), [
        'a',
        'b',
        'c',
      ]);
      controller.setSorting(false);
      expect(controller.sorting, isFalse);
      controller.dispose();
    },
  );

  test(
    'dispose does not cancel started work or notify on its completion',
    () async {
      final pending = Completer<void>();
      var notifications = 0;
      var completed = false;
      controller.addListener(() => notifications++);
      final operation = controller.run(() async {
        await pending.future;
        completed = true;
      }, pluginId: 'a');
      expect(notifications, 1);
      controller.dispose();
      pending.complete();
      await operation;
      expect(completed, isTrue);
      expect(notifications, 1);
      expect(controller.hasOperations, isFalse);
    },
  );
}
