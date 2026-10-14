import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/app/app_startup_coordinator.dart';
import 'package:hazuki/app/software_update/software_update_dialog_support.dart';
import 'package:hazuki/app/source_runtime/source_plugin_update_dialog_support.dart';
import 'package:hazuki/app/source_runtime/source_runtime_coordinator.dart';
import 'package:hazuki/app/source_runtime/source_update_dialog_support.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Runtime extends Mock implements SourceRuntimeCoordinator {}

class _Plugins extends Mock implements SourcePluginGateway {}

class _SoftwareDialogs extends Mock implements SoftwareUpdateDialogSupport {}

void main() {
  testWidgets(
    'app startup checks plugins before a source becomes ready without opening the plugins page',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'other_auto_source_update_check_enabled': false,
        'other_auto_software_update_check_enabled': false,
      });
      final runtime = _Runtime();
      final plugins = _Plugins();
      final bootstrap = Completer<void>();
      when(
        () => runtime.initConnectivityWatcher(
          scheduleSourceRecovery: any(named: 'scheduleSourceRecovery'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => runtime.bootstrapSourceRuntime(
          isMounted: any(named: 'isMounted'),
          onBootstrapStateChanged: any(named: 'onBootstrapStateChanged'),
          onSourceReady: any(named: 'onSourceReady'),
          scheduleSourceUpdateDialogCheck: any(
            named: 'scheduleSourceUpdateDialogCheck',
          ),
        ),
      ).thenAnswer((_) => bootstrap.future);
      when(runtime.dispose).thenAnswer((_) async {});
      when(plugins.checkStartupUpdates).thenAnswer((_) async {});
      when(() => plugins.indexError).thenReturn(null);
      when(() => plugins.availableUpdates).thenReturn([]);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: const Scaffold(body: Text('Home')),
        ),
      );
      final startup = HazukiAppStartupCoordinator(
        navigatorKey: navigator,
        sourceRuntimeCoordinator: runtime,
        sourceUpdateDialogSupport: const SourceUpdateDialogSupport(),
        softwareUpdateDialogSupport: _SoftwareDialogs(),
        sourcePluginUpdateDialogSupport: SourcePluginUpdateDialogSupport(
          gateway: plugins,
        ),
        isMounted: () => true,
      );
      addTearDown(() async {
        await startup.close();
        startup.dispose();
      });
      startup.initialize();
      await tester.pump();
      await tester.pumpAndSettle();
      verify(plugins.checkStartupUpdates).called(1);
      expect(bootstrap.isCompleted, isFalse);
      expect(startup.allowDiscoverInitialLoad, isFalse);
      bootstrap.complete();
      await tester.pumpAndSettle();
      verifyNever(plugins.checkStartupUpdates);
      expect(tester.takeException(), isNull);
    },
  );
}
