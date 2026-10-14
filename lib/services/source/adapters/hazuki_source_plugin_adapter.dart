import 'package:flutter/foundation.dart';
import '../../../models/source_meta.dart';
import '../../../shared/preferences/software_update_source.dart';
import '../gateways/source_plugin_gateway.dart';
import '../plugins/source_plugin_manager.dart';
import '../plugins/source_plugin_models.dart';

class HazukiSourcePluginAdapter implements SourcePluginGateway {
  HazukiSourcePluginAdapter(
    this.manager, {
    required this.metadataLoader,
    required this.settingLoader,
    required this.settingWriter,
    required this.actionRunner,
  });
  final SourcePluginManager manager;
  final Future<SourceMeta?> Function(String) metadataLoader;
  final Object? Function(String, String) settingLoader;
  final Future<void> Function(String, String, dynamic) settingWriter;
  final Future<dynamic> Function(String, String) actionRunner;
  @override
  List<InstalledSourcePlugin> get installed => manager.installed;
  @override
  List<String> get repositories => manager.repositories;
  @override
  Map<String, String> get errors => manager.errors;
  @override
  bool get checkingIndex => manager.checkingIndex;
  @override
  String? get indexError => manager.indexError;
  @override
  List<SourcePluginUpdate> get availableUpdates => manager.availableUpdates;
  @override
  List<SourcePluginIndexEntry> entriesFor(String repo) =>
      manager.entriesFor(repo);
  @override
  InstalledSourcePlugin? pluginFor(String id) => manager.pluginFor(id);
  @override
  Future<void> initialize() => manager.initialize();
  @override
  Future<void> checkStartupUpdates() => manager.checkStartupUpdates();
  @override
  Future<SoftwareUpdateSource> loadUpdateSource() => manager.loadUpdateSource();
  @override
  Future<void> setUpdateSource(SoftwareUpdateSource source) =>
      manager.setUpdateSource(source);
  @override
  Future<String> addRepository(
    String address, {
    String? branch,
    String path = 'plugins.json',
  }) => manager.addRepository(address, branch: branch, path: path);
  @override
  Future<void> refreshRepository(String repo) =>
      manager.refreshRepository(repo);
  @override
  Future<void> removeRepository(String repo) => manager.removeRepository(repo);
  @override
  Future<void> importPackage(List<int> bytes) => manager.importPackage(bytes);
  @override
  Future<void> installFromRepository(
    String repo,
    SourcePluginIndexEntry entry,
  ) => manager.installFromRepository(repo, entry);
  @override
  Future<void> setEnabled(String id, bool enabled) =>
      manager.setEnabled(id, enabled);
  @override
  Future<void> uninstall(String id) => manager.uninstall(id);
  @override
  Future<SourcePluginIndexEntry?> checkUpdate(String id) =>
      manager.checkUpdate(id);
  @override
  Future<SourceMeta?> loadMetadata(String id) => metadataLoader(id);
  @override
  Object? loadSetting(String id, String key) => settingLoader(id, key);
  @override
  Future<void> saveSetting(String id, String key, dynamic value) =>
      settingWriter(id, key, value);
  @override
  Future<dynamic> runAction(String id, String action) =>
      actionRunner(id, action);
  @override
  void addListener(VoidCallback listener) => manager.addListener(listener);
  @override
  void removeListener(VoidCallback listener) =>
      manager.removeListener(listener);
}
