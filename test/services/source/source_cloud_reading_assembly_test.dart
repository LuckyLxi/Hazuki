import 'package:hazuki/services/source/interaction/source_ui_service.dart';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/plugins/source_plugin_manager.dart';
import 'package:hazuki/services/source/runtime/source_runtime_assembly.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';
import 'package:hazuki/services/source/runtime/source_task_registry.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:shared_preferences/shared_preferences.dart';

late SourceUiService sourceUiService;

void main() {
  setUp(() {
    sourceUiService = SourceUiService();
  });
  tearDown(() {
    sourceUiService.detach();
  });
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'assembly starts signed-in history and drains cloud work on dispose',
    () async {
      SharedPreferences.setMockInitialValues({});
      final directory = await Directory.systemTemp.createTemp(
        'hazuki-cloud-assembly-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final plugins = SourcePluginManager(
        directory: () async => directory,
        legacyDirectories: [],
      );
      final assembly = SourceRuntimeAssembly(
        sourceUiService: sourceUiService,
        pluginManager: plugins,
        secureSessionStorage: MemorySourceSecureSessionStorage(),
      );
      var disposed = false;
      addTearDown(() async {
        if (!disposed) assembly.dispose();
        await assembly.whenSettled;
      });
      await assembly.runtimeRegistry.loadActiveSourcePreference();
      await plugins.importPackage(
        utf8.encode('''
      Hazuki.registerSource({id: 'cloud', name: 'Cloud', version: '1.0.0',
        search: {load: () => ({comics: []})},
        comic: {
          loadInfo: () => ({title: 'Comic'}),
          loadEp: () => ({images: []}),
          loadReadingProgress: () => null,
          loadReadingHistory: () => new Promise(() => {}),
          onReadingProgress: () => new Promise(() => {})
        }
      });
    '''),
      );
      await assembly.runtimeRegistry.activateSource('cloud');
      await assembly.ensureSourceInitialized('cloud');
      final owner = assembly.testing.handleFor('cloud');
      final tasks = assembly.gateways.taskControl as SourceTaskRegistry;
      await owner.session.saveSourceData('cloud', 'login_session', 'account');
      assembly.testing.notifyRuntimeView();

      final progress = assembly.gateways.readingProgressUploads;
      final upload = progress.reportReadingProgress({
        'comicId': 'comic',
        'chapterId': 'ep',
        'page': 1,
      }, sourceKey: 'cloud');
      final cancelled = expectLater(
        upload,
        throwsA(
          isA<SourceTaskCancelled>().having(
            (error) => error.reason,
            'reason',
            SourceTaskStopReason.ownerDisposed,
          ),
        ),
      );
      final pendingMethods = {'cloud.history.pages', 'cloud.upload'};
      final deadline = Stopwatch()..start();
      while (pendingMethods.isNotEmpty &&
          deadline.elapsed < const Duration(seconds: 5)) {
        pendingMethods.removeAll(
          tasks.activeTasks
              .where((task) => task.runtimeId != null)
              .map((task) => task.method),
        );
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      expect(pendingMethods, isEmpty);

      assembly.dispose();
      disposed = true;
      await assembly.whenSettled.timeout(const Duration(seconds: 5));
      expect(owner.hostExecutionGuards, isEmpty);
      expect(tasks.activeTasks, isEmpty);
      await cancelled;
      await owner.whenDisposed.timeout(const Duration(seconds: 5));
    },
  );
}
