import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/source_contract_models.dart';
import '../runtime/source_script_storage.dart';
import 'source_plugin_models.dart';
import 'source_presentation_metadata.dart';
import 'source_plugin_script_inspector.dart';

typedef PluginPackageValidator =
    Future<void> Function(SourcePluginManifest manifest, Directory directory);

/// Owns installed packages. A journal commits complete generations; interrupted
/// installs never replace the last committed registry or overwrite user data.
class SourcePluginManager extends ChangeNotifier implements SourceScriptStore {
  SourcePluginManager({
    Future<Directory> Function()? directory,
    Future<List<int>> Function(Uri url)? download,
    List<Directory>? legacyDirectories,
    this.validatePackage,
    this.onCatalogChanged,
  }) : _directory = directory ?? _defaultDirectory,
       _download = download ?? _downloadBytes,
       _legacyDirectories = legacyDirectories;

  final Future<Directory> Function() _directory;
  final Future<List<int>> Function(Uri url) _download;
  final List<Directory>? _legacyDirectories;
  PluginPackageValidator? validatePackage;
  Future<void> Function(List<SourceCatalogEntry>)? onCatalogChanged;
  final Map<String, InstalledSourcePlugin> _installed = {};
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
  Future<void> _tail = Future.value();
  Directory? _root;
  bool _disposed = false;

  List<InstalledSourcePlugin> get installed =>
      List.unmodifiable(_installed.values);
  List<String> get repositories => List.unmodifiable(_repositories);
  List<SourcePluginIndexEntry> entriesFor(String repository) =>
      List.unmodifiable(_indexes[repository] ?? const []);
  InstalledSourcePlugin? pluginFor(String id) => _installed[id];

  List<SourceCatalogEntry> get catalog => _installed.values
      .where(
        (plugin) =>
            plugin.enabled && !_fileErrors.containsKey(plugin.manifest.id),
      )
      .map(
        (plugin) => SourceCatalogEntry(
          key: plugin.manifest.id,
          name: plugin.manifest.name,
          fileName: plugin.manifest.entry,
          pluginVersion: plugin.manifest.version,
          pluginDirectory: p.join(_root!.path, plugin.directory),
          presentation: plugin.manifest.presentation,
        ),
      )
      .toList(growable: false);

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
    if (records.isNotEmpty) {
      final state = jsonDecode(await records.first.readAsString()) as Map;
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
        final plugin = InstalledSourcePlugin.fromJson(
          Map<String, dynamic>.from(raw as Map),
        );
        _installed[plugin.manifest.id] = plugin;
        _historicalPresentations[plugin.manifest.id] =
            historicalSourcePresentation(plugin.manifest.presentation);
        if (!await File(
          p.join(_root!.path, plugin.directory, plugin.manifest.entry),
        ).exists()) {
          _fileErrors[plugin.manifest.id] = 'plugin_entry_missing';
        }
      }
      _repositories.addAll((state['repositories'] as List).cast<String>());
    }
    await _backupLegacyScripts();
    await onCatalogChanged?.call(catalog);
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
    final file = File(p.join(_root!.path, 'registry-${_generation()}.json'));
    final pending = File('${file.path}.pending');
    await pending.writeAsString(
      jsonEncode({
        'schemaVersion': 1,
        'historicalPresentations': _historicalPresentations,
        'repositories': _repositories,
        'installed': _installed.values.map((item) => item.toJson()).toList(),
      }),
      flush: true,
    );
    await pending.rename(file.path);
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
    final key = url.toString();
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
    final data = await _download(uri);
    if (data.length > 2 * 1024 * 1024) {
      throw const SourcePluginException('plugin_index_too_large');
    }
    return parsePluginIndex(utf8.decode(data));
  }

  Future<void> refreshRepository(String repository) => _serialize(() async {
    _indexes[repository] = await _readIndex(Uri.parse(repository));
    _notify();
  });

  Future<void> removeRepository(String repository) => _serialize(() async {
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
  ) => _serialize(() async {
    if (!_repositories.contains(repository)) {
      throw const SourcePluginException('plugin_repository_not_added');
    }
    await _install(
      await _download(entry.downloadUrl),
      repository: repository,
      expected: entry,
    );
  });

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
      );
      final oldPresentation = _historicalPresentations[manifest.id];
      _historicalPresentations[manifest.id] = historicalSourcePresentation(
        manifest.presentation,
      );
      _installed[manifest.id] = plugin;
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
        if (oldError != null) _fileErrors[manifest.id] = oldError;
        await onCatalogChanged?.call(catalog);
        rethrow;
      }
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
    _installed[id] = old.copyWith(enabled: enabled);
    try {
      await onCatalogChanged?.call(catalog);
      await _commit();
    } catch (_) {
      _installed[id] = old;
      await onCatalogChanged?.call(catalog);
      rethrow;
    }
    _notify();
  });

  Future<void> uninstall(String id) => _serialize(() async {
    final old = _requirePlugin(id);
    _installed.remove(id);
    _runtimeErrors.remove(id);
    final oldError = _fileErrors.remove(id);
    try {
      await onCatalogChanged?.call(catalog);
      await _commit();
    } catch (_) {
      _installed[id] = old;
      if (oldError != null) _fileErrors[id] = oldError;
      await onCatalogChanged?.call(catalog);
      rethrow;
    }
    // Retain packages as rollback/edited-script backups and retain all source data.
    _notify();
  });

  Future<SourcePluginIndexEntry?> checkUpdate(String id) async {
    await initialize();
    final plugin = _requirePlugin(id);
    if (plugin.repository == null) return null;
    final entries = await _readIndex(Uri.parse(plugin.repository!));
    final entry = entries.where((entry) => entry.id == id).firstOrNull;
    return entry != null &&
            (isPluginVersion(plugin.manifest.version)
                ? comparePluginVersions(
                        entry.version,
                        plugin.manifest.version,
                      ) >
                      0
                : entry.version != plugin.manifest.version)
        ? entry
        : null;
  }

  InstalledSourcePlugin _requirePlugin(String id) =>
      _installed[id] ??
      (throw SourcePluginException('plugin_not_installed', id));

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
