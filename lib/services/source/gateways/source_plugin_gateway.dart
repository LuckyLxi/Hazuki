import 'package:flutter/foundation.dart';
import '../../../models/source_meta.dart';
import '../../../shared/preferences/software_update_source.dart';
import '../plugins/source_plugin_models.dart';

abstract interface class SourcePluginGateway implements Listenable {
  List<InstalledSourcePlugin> get installed;
  List<String> get repositories;
  Map<String, String> get errors;
  bool get checkingIndex;
  String? get indexError;
  List<SourcePluginUpdate> get availableUpdates;
  List<SourcePluginIndexEntry> entriesFor(String repository);
  InstalledSourcePlugin? pluginFor(String id);
  Future<void> initialize();
  Future<void> checkStartupUpdates();
  Future<SoftwareUpdateSource> loadUpdateSource();
  Future<void> setUpdateSource(SoftwareUpdateSource source);
  Future<String> addRepository(
    String address, {
    String? branch,
    String path = 'plugins.json',
  });
  Future<void> refreshRepository(String repository);
  Future<void> removeRepository(String repository);
  Future<void> importPackage(List<int> bytes);
  Future<void> installFromRepository(
    String repository,
    SourcePluginIndexEntry entry,
  );
  Future<void> setEnabled(String id, bool enabled);
  Future<void> uninstall(String id);
  Future<SourcePluginIndexEntry?> checkUpdate(String id);
  Future<SourceMeta?> loadMetadata(String id);
  Object? loadSetting(String id, String key);
  Future<void> saveSetting(String id, String key, dynamic value);
  Future<dynamic> runAction(String id, String action);
}
