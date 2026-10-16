import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/preferences/hazuki_preference_keys.dart';
import '../../../shared/preferences/software_update_source.dart';
import '../models/source_contract_models.dart';
import '../runtime/source_script_storage.dart';
import 'source_plugin_models.dart';
import 'source_presentation_metadata.dart';
import 'source_plugin_script_inspector.dart';
import 'source_plugin_repository.dart';

typedef PluginPackageValidator =
    Future<void> Function(SourcePluginManifest manifest, Directory directory);

/// Owns installed packages. Atomic registry replacement commits complete
/// generations; interrupted installs never overwrite committed user data.
class SourcePluginManager extends ChangeNotifier implements SourceScriptStore {
  SourcePluginManager({
    Future<Directory> Function()? directory,
    Future<List<int>> Function(Uri url)? download,
    List<Directory>? legacyDirectories,
    Future<SoftwareUpdateSource> Function()? loadUpdateSource,
    this.validatePackage,
    this.onCatalogChanged,
  }) : _directory = directory ?? _defaultDirectory,
       _download = download ?? _downloadBytes,
       _loadUpdateSource =
           loadUpdateSource ?? loadSoftwareUpdateSourcePreference,
       _legacyDirectories = legacyDirectories;

  final Future<Directory> Function() _directory;
  final Future<List<int>> Function(Uri url) _download;
  final Future<SoftwareUpdateSource> Function() _loadUpdateSource;
  final List<Directory>? _legacyDirectories;
  PluginPackageValidator? validatePackage;
  Future<void> Function(List<SourceCatalogEntry>)? onCatalogChanged;
  final Map<String, InstalledSourcePlugin> _installed = {};
  final Map<String, String> _installedVersions = {};
  // Pending edits change stored files without publishing a new runtime revision.
  // Keep these entries stable when another plugin republishes the catalog.
  final Map<String, SourceCatalogEntry> _deferredCatalogEntries = {};
  static const installedPluginsFileName = 'installed_plugins.json';
  final Map<String, Map<String, dynamic>> _historicalPresentations = {};

  Map<String, dynamic> historicalPresentationFor(String id) =>
      historicalSourcePresentation(
        _historicalPresentations[id.trim()] ?? const {},
      );
  final List<String> _repositories = [];
  final Map<String, List<SourcePluginIndexEntry>> _indexes = {};
  final Map<String, String> _fileErrors = {};
  final Map<String, String> _runtimeErrors = {};
  Map<String, String> get errors =>
      Map.unmodifiable({..._fileErrors, ..._runtimeErrors});
  void recordRuntimeError(String id, String? error) {
    if (_runtimeErrors[id] == error) return;
    if (error == null) {
      _runtimeErrors.remove(id);
    } else {
      _runtimeErrors[id] = error;
    }
    _notify();
  }

  Future<void>? _initializing;
  Future<void>? _startupUpdateCheck;
  bool _checkingIndex = false;
  String? _indexError;
  Future<void> _tail = Future.value();
  Directory? _root;
  bool _disposed = false;

  List<InstalledSourcePlugin> get installed =>
      List.unmodifiable(_installed.values);
  List<String> get repositories => List.unmodifiable(_repositories);
  List<SourcePluginIndexEntry> entriesFor(String repository) =>
      List.unmodifiable(_indexes[repository] ?? const []);
  InstalledSourcePlugin? pluginFor(String id) => _installed[id];
  bool get checkingIndex => _checkingIndex;
  String? get indexError => _indexError;
  List<SourcePluginUpdate> get availableUpdates => List.unmodifiable([
    for (final entry in entriesFor(sourcePluginsRepositoryUrl))
      if (_installed[entry.id] case final plugin?)
        if (plugin.repository == sourcePluginsRepositoryUrl)
          if (_installedVersions[entry.id] case final version?)
            if (_isNewer(entry.version, version))
              SourcePluginUpdate(
                plugin: plugin,
                entry: entry,
                localVersion: version,
              ),
  ]);

  bool _isNewer(String remote, String local) => isPluginVersion(local)
      ? comparePluginVersions(remote, local) > 0
      : remote != local;

  /// Shared by startup and its dialog; a page visit never starts another fetch.
  Future<void> checkStartupUpdates() =>
      _startupUpdateCheck ??= _checkStartupUpdates();

  Future<void> _checkStartupUpdates() async {
    try {
      await refreshRepository(sourcePluginsRepositoryUrl);
    } catch (error) {
      _indexError = error.toString();
      _notify();
    }
  }

  Future<SoftwareUpdateSource> loadUpdateSource() => _loadUpdateSource();

  Future<void> setUpdateSource(SoftwareUpdateSource source) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
      hazukiSoftwareUpdateSourcePreferenceKey,
      source.preferenceValue,
    )) {
      throw StateError('plugin_update_source_not_saved');
    }
    _notify();
  }

  Future<List<int>> _downloadPluginIndexBytes(Uri url) async =>
      _download(resolveSourcePluginIndexUrl(url, await _loadUpdateSource()));

  List<SourceCatalogEntry> get catalog => _installed.values
      .where(
        (plugin) =>
            plugin.enabled && !_fileErrors.containsKey(plugin.manifest.id),
      )
      .map(_catalogEntryFor)
      .toList(growable: false);

  SourceCatalogEntry _catalogEntryFor(InstalledSourcePlugin plugin) =>
      _deferredCatalogEntries[plugin.manifest.id] ??
      SourceCatalogEntry(
        key: plugin.manifest.id,
        name: plugin.manifest.name,
        fileName: plugin.manifest.entry,
        pluginVersion: plugin.manifest.version,
        pluginDirectory: p.join(_root!.path, plugin.directory),
        presentation: plugin.manifest.presentation,
      );

  static Future<Directory> _defaultDirectory() async => Directory(
    p.join((await getApplicationSupportDirectory()).path, 'source_plugins'),
  );

  static Future<List<int>> _downloadBytes(Uri url) async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 60),
      ),
    );
    try {
      final response = await dio.get<ResponseBody>(
        url.toString(),
        options: Options(responseType: ResponseType.stream),
      );
      final result = <int>[];
      await for (final bytes in response.data!.stream) {
        result.addAll(bytes);
        if (result.length > 8 * 1024 * 1024) {
          throw const SourcePluginException('plugin_download_too_large');
        }
      }
      return result;
    } finally {
      dio.close(force: true);
    }
  }

  Future<void> initialize() => _initializing ??= _initialize();

  Future<void> _initialize() async {
    _root = await _directory();
    await _root!.create(recursive: true);
    final versionFile = File(p.join(_root!.path, installedPluginsFileName));
    final records = await _root!
        .list()
        .where(
          (entry) =>
              entry is File &&
              p.basename(entry.path).startsWith('registry-') &&
              entry.path.endsWith('.json'),
        )
        .cast<File>()
        .toList();
    records.sort((a, b) => b.path.compareTo(a.path));
    final hasVersionFile = await versionFile.exists();
    if (hasVersionFile || records.isNotEmpty) {
      final state =
          jsonDecode(
                await (hasVersionFile ? versionFile : records.first)
                    .readAsString(),
              )
              as Map;
      if (state['schemaVersion'] != 1) {
        throw const SourcePluginException('plugin_invalid_store');
      }
      if (state['historicalPresentations'] case final Map history) {
        for (final entry in history.entries) {
          if (entry.key is String && entry.value is Map) {
            _historicalPresentations[entry.key
                as String] = historicalSourcePresentation(
              Map<String, dynamic>.from(entry.value as Map),
            );
          }
        }
      }
      for (final raw in state['installed'] as List) {
        final record = Map<String, dynamic>.from(raw as Map);
        if (record['repository'] case final String repository) {
          record['repository'] = canonicalSourcePluginUrl(repository);
        }
        final plugin = InstalledSourcePlugin.fromJson(record);
        _installed[plugin.manifest.id] = plugin;
        _installedVersions[plugin.manifest.id] = plugin.manifest.version;
        _historicalPresentations[plugin.manifest.id] =
            historicalSourcePresentation(plugin.manifest.presentation);
        if (!await File(
          p.join(_root!.path, plugin.directory, plugin.manifest.entry),
        ).exists()) {
          _fileErrors[plugin.manifest.id] = 'plugin_entry_missing';
        }
      }
      _repositories.addAll(
        (state['repositories'] as List)
            .cast<String>()
            .map(canonicalSourcePluginUrl)
            .toSet(),
      );
      if (state['plugins'] case final List versions) {
        for (final record in versions.whereType<Map>()) {
          if (record['id'] case final String id) {
            if (record['version'] case final String version) {
              if (_installed.containsKey(id)) _installedVersions[id] = version;
            }
          }
        }
      }
    }
    if (!_repositories.contains(sourcePluginsRepositoryUrl)) {
      _repositories.insert(0, sourcePluginsRepositoryUrl);
    }
    await _backupLegacyScripts();
    await onCatalogChanged?.call(catalog);
    if (!hasVersionFile && _installed.isNotEmpty) await _commit();
    final cachedIndex = File(p.join(_root!.path, 'plugins.json'));
    if (await cachedIndex.exists()) {
      try {
        _indexes[sourcePluginsRepositoryUrl] = parsePluginIndex(
          await cachedIndex.readAsString(),
        );
      } catch (_) {
        // A stale or damaged index can be replaced by the startup fetch.
      }
    }
    _notify();
  }

  Future<void> _backupLegacyScripts() async {
    final marker = File(p.join(_root!.path, 'legacy-backup-complete'));
    if (await marker.exists()) return;
    final bases =
        _legacyDirectories ??
        <Directory>[
          Directory(
            p.join(
              (await getApplicationSupportDirectory()).path,
              'comic_source',
            ),
          ),
          if (Platform.isWindows)
            Directory(
              p.join(
                File(Platform.resolvedExecutable).parent.path,
                'comic_source',
              ),
            ),
        ];
    final backup = Directory(p.join(_root!.path, 'legacy_backup'));
    for (var i = 0; i < bases.length; i++) {
      final base = bases[i];
      if (!await base.exists()) continue;
      await for (final entry in base.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entry is! File || !entry.path.endsWith('.js')) continue;
        final target = File(
          p.join(backup.path, '$i', p.relative(entry.path, from: base.path)),
        );
        await target.parent.create(recursive: true);
        if (!await target.exists()) await entry.copy(target.path);
      }
    }
    await marker.writeAsString('1', flush: true);
  }

  Future<T> _serialize<T>(Future<T> Function() action) {
    final next = _tail.then((_) async {
      await initialize();
      if (_disposed) throw StateError('plugin_manager_disposed');
      return action();
    });
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  String _generation() =>
      '${DateTime.now().microsecondsSinceEpoch.toString().padLeft(20, '0')}-${Random.secure().nextInt(0x7fffffff)}';

  Future<void> _commit() async {
    final file = File(p.join(_root!.path, installedPluginsFileName));
    final pending = File('${file.path}.pending');
    await pending.writeAsString(
      jsonEncode({
        'schemaVersion': 1,
        'plugins': [
          for (final plugin in _installed.values)
            {'id': plugin.manifest.id, 'version': plugin.manifest.version},
        ],
        'historicalPresentations': _historicalPresentations,
        'repositories': _repositories,
        'installed': _installed.values.map((item) => item.toJson()).toList(),
      }),
      flush: true,
    );
    await pending.rename(file.path);
    _installedVersions
      ..clear()
      ..addEntries(
        _installed.values.map(
          (plugin) => MapEntry(plugin.manifest.id, plugin.manifest.version),
        ),
      );
  }

  /// Resolve a public GitHub repo, a tree/blob URL, or an HTTPS JSON URL.
  Future<Uri> resolveRepository(
    String address, {
    String? branch,
    String path = 'plugins.json',
  }) async {
    final uri = Uri.tryParse(address.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const SourcePluginException('plugin_invalid_repository');
    }
    if (uri.host != 'github.com') return uri;
    final parts = uri.pathSegments;
    if (parts.length < 2 || !isPluginPath(path)) {
      throw const SourcePluginException('plugin_invalid_repository');
    }
    final owner = parts[0];
    final repo = parts[1].replaceFirst(RegExp(r'\.git$'), '');
    var selectedBranch = branch;
    var selectedPath = path;
    if (parts.length > 3 && (parts[2] == 'tree' || parts[2] == 'blob')) {
      selectedBranch ??= parts[3];
      final branchParts = selectedBranch.split('/');
      final branchLength =
          parts.skip(3).take(branchParts.length).join('/') == selectedBranch
          ? branchParts.length
          : 1;
      if (parts.length > 3 + branchLength) {
        selectedPath = parts.skip(3 + branchLength).join('/');
        if (parts[2] == 'tree') selectedPath = '$selectedPath/$path';
      }
    }
    if (selectedBranch == null || selectedBranch.isEmpty) {
      final info = jsonDecode(
        utf8.decode(
          await _download(Uri.https('api.github.com', '/repos/$owner/$repo')),
        ),
      );
      selectedBranch = (info as Map)['default_branch'] as String?;
      if (selectedBranch == null || selectedBranch.isEmpty) {
        throw const SourcePluginException('plugin_repository_not_found');
      }
    }
    return Uri(
      scheme: 'https',
      host: 'raw.githubusercontent.com',
      pathSegments: [owner, repo, selectedBranch, ...selectedPath.split('/')],
    );
  }

  Future<String> addRepository(
    String address, {
    String? branch,
    String path = 'plugins.json',
  }) => _serialize(() async {
    final url = await resolveRepository(address, branch: branch, path: path);
    final index = await _readIndex(url);
    final key = canonicalSourcePluginUrl(url.toString());
    if (!_repositories.contains(key)) {
      _repositories.add(key);
      try {
        await _commit();
      } catch (_) {
        _repositories.remove(key);
        rethrow;
      }
    }
    _indexes[key] = index;
    _notify();
    return key;
  });

  Future<List<SourcePluginIndexEntry>> _readIndex(Uri uri) async {
    final data = await _downloadPluginIndexBytes(uri);
    if (data.length > 2 * 1024 * 1024) {
      throw const SourcePluginException('plugin_index_too_large');
    }
    final content = utf8.decode(data);
    final entries = parsePluginIndex(content);
    if (canonicalSourcePluginUrl(uri.toString()) ==
        sourcePluginsRepositoryUrl) {
      final file = File(p.join(_root!.path, 'plugins.json'));
      final pending = File('${file.path}.pending');
      await pending.writeAsString(content, flush: true);
      await pending.rename(file.path);
    }
    return entries;
  }

  Future<void> refreshRepository(String repository) => _serialize(() async {
    final builtin = repository == sourcePluginsRepositoryUrl;
    if (builtin) {
      _checkingIndex = true;
      _indexError = null;
      _notify();
    }
    try {
      _indexes[repository] = await _readIndex(Uri.parse(repository));
    } catch (error) {
      if (builtin) _indexError = error.toString();
      rethrow;
    } finally {
      if (builtin) _checkingIndex = false;
      _notify();
    }
  });

  Future<void> removeRepository(String repository) => _serialize(() async {
    if (repository == sourcePluginsRepositoryUrl) {
      throw const SourcePluginException('plugin_builtin_repository');
    }
    final previous = List<String>.of(_repositories);
    _repositories.remove(repository);
    try {
      await _commit();
    } catch (_) {
      _repositories
        ..clear()
        ..addAll(previous);
      rethrow;
    }
    _indexes.remove(repository);
    _notify();
  });

  Future<void> installFromRepository(
    String repository,
    SourcePluginIndexEntry entry,
  ) async {
    await initialize();
    if (_disposed) throw StateError('plugin_manager_disposed');
    if (!_repositories.contains(repository)) {
      throw const SourcePluginException('plugin_repository_not_added');
    }
    if (_installed[entry.id] case final installed?) {
      if (installed.repository != repository) {
        throw const SourcePluginException('plugin_source_conflict');
      }
    }
    // Downloads are independent; catalog changes and registry writes must
    // still commit one at a time.
    final bytes = await _download(entry.downloadUrl);
    await _serialize(() async {
      if (!_repositories.contains(repository)) {
        throw const SourcePluginException('plugin_repository_not_added');
      }
      await _install(bytes, repository: repository, expected: entry);
    });
  }

  Future<void> importPackage(List<int> bytes) =>
      _serialize(() => _install(bytes));

  Future<void> _install(
    List<int> bytes, {
    String? repository,
    SourcePluginIndexEntry? expected,
  }) async {
    if (bytes.length > 8 * 1024 * 1024) {
      throw const SourcePluginException('plugin_package_too_large');
    }
    final staging = Directory(p.join(_root!.path, 'packages', _generation()));
    await staging.create(recursive: true);
    var committed = false;
    try {
      final String script;
      try {
        script = utf8.decode(bytes);
      } on FormatException {
        throw const SourcePluginException('plugin_invalid_encoding');
      }
      final manifest = await SourcePluginScriptInspector().inspect(script);
      await File(
        p.join(staging.path, manifest.entry),
      ).writeAsString(script, flush: true);
      if (expected != null &&
          (expected.id != manifest.id ||
              expected.version != manifest.version)) {
        throw const SourcePluginException('plugin_index_package_mismatch');
      }
      final old = _installed[manifest.id];
      if (old != null && old.repository != repository) {
        throw const SourcePluginException(
          'plugin_source_conflict',
          'Uninstall the existing package before changing its source; its data will be kept.',
        );
      }
      await validatePackage?.call(manifest, staging);
      final plugin = InstalledSourcePlugin(
        manifest: manifest,
        directory: p
            .relative(staging.path, from: _root!.path)
            .replaceAll('\\', '/'),
        repository: repository,
        enabled: old?.enabled ?? true,
        editBackup: old?.editBackup,
      );
      final oldPresentation = _historicalPresentations[manifest.id];
      _historicalPresentations[manifest.id] = historicalSourcePresentation(
        manifest.presentation,
      );
      _installed[manifest.id] = plugin;
      final deferredCatalogEntry = _deferredCatalogEntries.remove(manifest.id);
      final oldError = _fileErrors.remove(manifest.id);
      _runtimeErrors.remove(manifest.id);
      try {
        await onCatalogChanged?.call(catalog);
        await _commit();
        committed = true;
      } catch (_) {
        if (oldPresentation == null) {
          _historicalPresentations.remove(manifest.id);
        } else {
          _historicalPresentations[manifest.id] = oldPresentation;
        }
        if (old == null) {
          _installed.remove(manifest.id);
        } else {
          _installed[manifest.id] = old;
        }
        if (deferredCatalogEntry != null) {
          _deferredCatalogEntries[manifest.id] = deferredCatalogEntry;
        }
        if (oldError != null) _fileErrors[manifest.id] = oldError;
        await onCatalogChanged?.call(catalog);
        rethrow;
      }
      await _discardUnusedEditDirectory(old?.directory);
      _notify();
    } finally {
      // Staging uses a generated directory and a fixed main.js filename.
      if (!committed &&
          await staging.exists() &&
          p.isWithin(_root!.path, staging.path)) {
        await staging.delete(recursive: true);
      }
    }
  }

  Future<void> setEnabled(String id, bool enabled) => _serialize(() async {
    final old = _requirePlugin(id);
    final deferredCatalogEntry = enabled != old.enabled
        ? _deferredCatalogEntries.remove(id)
        : null;
    _installed[id] = old.copyWith(enabled: enabled);
    var committed = false;
    try {
      await _commit();
      committed = true;
      await onCatalogChanged?.call(catalog);
    } catch (_) {
      _installed[id] = old;
      if (deferredCatalogEntry != null) {
        _deferredCatalogEntries[id] = deferredCatalogEntry;
      }
      if (committed) {
        await _commit();
        await onCatalogChanged?.call(catalog);
      }
      rethrow;
    }
    _notify();
  });

  Future<void> uninstall(String id) => _serialize(() async {
    final old = _requirePlugin(id);
    _installed.remove(id);
    final oldError = _fileErrors.remove(id);
    var committed = false;
    try {
      await _commit();
      committed = true;
      await onCatalogChanged?.call(catalog);
    } catch (_) {
      _installed[id] = old;
      if (oldError != null) _fileErrors[id] = oldError;
      if (committed) {
        await _commit();
        await onCatalogChanged?.call(catalog);
      }
      rethrow;
    }
    // Retain packages as rollback/edited-script backups and retain all source data.
    _deferredCatalogEntries.remove(id);
    _runtimeErrors.remove(id);
    _notify();
  });

  Future<SourcePluginIndexEntry?> checkUpdate(String id) async {
    await initialize();
    final plugin = _requirePlugin(id);
    if (plugin.repository == null) return null;
    final builtin = plugin.repository == sourcePluginsRepositoryUrl;
    if (builtin && _startupUpdateCheck != null) await _startupUpdateCheck;
    final entries = builtin
        ? entriesFor(sourcePluginsRepositoryUrl)
        : await _readIndex(Uri.parse(plugin.repository!));
    final entry = entries.where((entry) => entry.id == id).firstOrNull;
    return entry != null &&
            _isNewer(
              entry.version,
              _installedVersions[id] ?? plugin.manifest.version,
            )
        ? entry
        : null;
  }

  InstalledSourcePlugin _requirePlugin(String id) =>
      _installed[id] ??
      (throw SourcePluginException('plugin_not_installed', id));

  /// Re-fetch the index even when the installed version is already current.
  Future<bool> redownload(String id) async {
    await initialize();
    final repository = _requirePlugin(id).repository;
    if (repository == null) return false;
    await refreshRepository(repository);
    final entry = entriesFor(
      repository,
    ).where((entry) => entry.id == id).firstOrNull;
    if (entry == null) {
      throw SourcePluginException('plugin_not_found_in_index', id);
    }
    await installFromRepository(repository, entry);
    return true;
  }

  Future<bool> hasEditBackup(String id) async {
    await initialize();
    final backup = _installed[id]?.editBackup;
    return backup != null &&
        await File(
          p.join(_root!.path, backup.directory, backup.manifest.entry),
        ).exists();
  }

  Future<void> saveEditedScript(String id, String content) =>
      _serialize(() async {
        if (utf8.encode(content).length > 8 * 1024 * 1024) {
          throw const SourcePluginException('plugin_package_too_large');
        }
        final old = _requirePlugin(id);
        final previousCatalogEntry = _catalogEntryFor(old);
        // Verify the previous script before making it the new backup.
        await File(
          p.join(_root!.path, old.directory, old.manifest.entry),
        ).readAsString();
        final staging = Directory(p.join(_root!.path, 'edits', _generation()));
        await staging.create(recursive: true);
        var committed = false;
        try {
          await File(
            p.join(staging.path, old.manifest.entry),
          ).writeAsString(content, flush: true);
          _installed[id] = old.copyWith(
            directory: p
                .relative(staging.path, from: _root!.path)
                .replaceAll('\\', '/'),
            customEdited: true,
            editBackup: SourcePluginScriptBackup(
              manifest: old.manifest,
              directory: old.directory,
              customEdited: old.customEdited,
            ),
          );
          try {
            await _commit();
            committed = true;
          } catch (_) {
            _installed[id] = old;
            rethrow;
          }
          // Keep the running engine until the requested restart/reload.
          _deferredCatalogEntries[id] = previousCatalogEntry;
          await _discardUnusedEditDirectory(old.editBackup?.directory);
          _notify();
        } finally {
          if (!committed &&
              await staging.exists() &&
              p.isWithin(_root!.path, staging.path)) {
            await staging.delete(recursive: true);
          }
        }
      });

  Future<bool> restoreEditBackup(String id) => _serialize(() async {
    final old = _requirePlugin(id);
    final previousCatalogEntry = _catalogEntryFor(old);
    final backup = old.editBackup;
    if (backup == null) return false;
    if (!await File(
      p.join(_root!.path, backup.directory, backup.manifest.entry),
    ).exists()) {
      throw const SourcePluginException('plugin_entry_missing');
    }
    _installed[id] = InstalledSourcePlugin(
      manifest: backup.manifest,
      directory: backup.directory,
      repository: old.repository,
      enabled: old.enabled,
      customEdited: backup.customEdited,
    );
    final oldPresentation = _historicalPresentations[id];
    _historicalPresentations[id] = historicalSourcePresentation(
      backup.manifest.presentation,
    );
    try {
      await _commit();
    } catch (_) {
      _installed[id] = old;
      if (oldPresentation == null) {
        _historicalPresentations.remove(id);
      } else {
        _historicalPresentations[id] = oldPresentation;
      }
      rethrow;
    }
    _deferredCatalogEntries[id] = previousCatalogEntry;
    _fileErrors.remove(id);
    await _discardUnusedEditDirectory(old.directory);
    _notify();
    return true;
  });

  Future<void> _discardUnusedEditDirectory(String? relative) async {
    if (relative == null ||
        _installed.values.any(
          (plugin) =>
              plugin.directory == relative ||
              plugin.editBackup?.directory == relative,
        )) {
      return;
    }
    final target = p.normalize(p.join(_root!.path, relative));
    if (!p.isWithin(p.join(_root!.path, 'edits'), target)) return;
    try {
      if (await Directory(target).exists()) {
        await Directory(target).delete(recursive: true);
      }
    } on FileSystemException {
      // Cleanup must not turn an already committed save into a failure.
    }
  }

  @override
  Future<File> sourceFileFor(
    String sourceKey, {
    bool ensureDirectory = false,
  }) async {
    await initialize();
    final plugin = _requirePlugin(sourceKey);
    return File(p.join(_root!.path, plugin.directory, plugin.manifest.entry));
  }

  @override
  Future<File> ensureLocalSourceFile(String sourceKey) =>
      sourceFileFor(sourceKey);
  @override
  Future<String?> readIfExists(String sourceKey) async =>
      await exists(sourceKey)
      ? (await sourceFileFor(sourceKey)).readAsString()
      : null;
  @override
  Future<bool> exists(String sourceKey) async {
    await initialize();
    return _installed.containsKey(sourceKey) &&
        await (await sourceFileFor(sourceKey)).exists();
  }

  @override
  Future<void> write(String sourceKey, String content) async {
    final file = await sourceFileFor(sourceKey);
    await file.writeAsString(content, flush: true);
  }

  @override
  Future<void> delete(String sourceKey) => uninstall(sourceKey);
  @override
  Future<bool> isCustomEdited(String sourceKey) async {
    await initialize();
    return _requirePlugin(sourceKey).customEdited;
  }

  @override
  Future<void> setCustomEdited(String sourceKey, bool value) =>
      _serialize(() async {
        final old = _requirePlugin(sourceKey);
        _installed[sourceKey] = old.copyWith(customEdited: value);
        try {
          await _commit();
        } catch (_) {
          _installed[sourceKey] = old;
          rethrow;
        }
        _notify();
      });

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    super.dispose();
  }
}
