import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/common/source_prefs_keys.dart';
import 'package:hazuki/services/source/plugins/source_plugin_manager.dart';
import 'package:hazuki/services/source/runtime/source_runtime_assembly.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'source_plugins_test.dart' show package;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late SourceRuntimeAssembly assembly;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('hazuki_cache_settings_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => directory.path,
        );
    assembly = SourceRuntimeAssembly(
      secureSessionStorage: MemorySourceSecureSessionStorage(),
      pluginManager: SourcePluginManager(
        directory: () async => Directory('${directory.path}/plugins'),
        legacyDirectories: [],
      ),
    );
  });
  tearDown(() async {
    assembly.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    await directory.delete(recursive: true);
  });

  test('persists cache settings before any source is installed', () async {
    await assembly.runtimeRegistry.loadActiveSourcePreference();
    expect(assembly.runtimeRegistry.activeSourceKey, isNull);
    final settings = assembly.gateways.settingsGateway;
    final maxBytes = SourcePrefsKeys.defaultCacheMaxBytes * 2;
    await settings.setImageCacheMaxBytes(maxBytes);
    await settings.setImageCacheAutoCleanMode('seven_days');
    final status = await settings.getImageCacheStatus();
    final prefs = await SharedPreferences.getInstance();
    expect(settings.imageCacheMaxBytes, maxBytes);
    expect(status['maxBytes'], maxBytes);
    expect(status['autoCleanMode'], 'seven_days');
    expect(prefs.getInt(SourcePrefsKeys.cacheMaxBytes), maxBytes);
    expect(prefs.getString(SourcePrefsKeys.cacheAutoCleanMode), 'seven_days');
  });

  test(
    'loads saved cache settings after uninstalling the last source',
    () async {
      final maxBytes = SourcePrefsKeys.defaultCacheMaxBytes * 2;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(SourcePrefsKeys.cacheMaxBytes, maxBytes);
      await prefs.setString(SourcePrefsKeys.cacheAutoCleanMode, 'seven_days');
      await assembly.runtimeRegistry.loadActiveSourcePreference();
      await assembly.plugins.importPackage(package());
      await assembly.plugins.uninstall('independent');
      expect(assembly.runtimeRegistry.activeSourceKey, isNull);
      final settings = assembly.gateways.settingsGateway;
      final status = await settings.getImageCacheStatus();
      expect(status['maxBytes'], maxBytes);
      expect(status['autoCleanMode'], 'seven_days');
      await settings.setImageCacheMaxBytes(maxBytes * 2);
      expect(prefs.getInt(SourcePrefsKeys.cacheMaxBytes), maxBytes * 2);
    },
  );
}
