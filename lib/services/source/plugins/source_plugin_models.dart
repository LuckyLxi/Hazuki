import 'source_search_capabilities.dart';
import 'dart:convert';
import 'source_plugin_buttons.dart';
import 'source_plugin_exception.dart';

export 'source_plugin_exception.dart';

enum SourcePluginActionLocation { plugin, reading, other, lab, advanced, lines }

SourcePluginActionLocation sourcePluginActionLocation(Object? value) {
  if (value == null) return SourcePluginActionLocation.plugin;
  for (final location in SourcePluginActionLocation.values) {
    if (value == location.name) return location;
  }
  throw SourcePluginException('plugin_invalid_action_location', '$value');
}

class SourcePluginAction {
  const SourcePluginAction({
    required this.id,
    required this.title,
    this.location = SourcePluginActionLocation.plugin,
  });

  final String id;
  final Object title;
  final SourcePluginActionLocation location;

  static List<SourcePluginAction> parseList(Object? value) {
    if (value == null) return const [];
    if (value is! List) {
      throw const SourcePluginException('plugin_invalid_actions');
    }
    return value
        .map((item) {
          if (item is! Map ||
              item['id'] is! String ||
              (item['id'] as String).isEmpty) {
            throw const SourcePluginException('plugin_invalid_actions');
          }
          return SourcePluginAction(
            id: item['id'] as String,
            title: item['title'] ?? item['id'],
            location: sourcePluginActionLocation(item['location']),
          );
        })
        .toList(growable: false);
  }
}

/// Setting controls can be assigned to the active plugin's lines page.
SourcePluginActionLocation sourcePluginSettingLocation(Object? value) {
  final location = sourcePluginActionLocation(value);
  if (location != SourcePluginActionLocation.plugin &&
      location != SourcePluginActionLocation.lines) {
    throw SourcePluginException('plugin_invalid_setting_location', '$value');
  }
  return location;
}

class SourcePluginManifest {
  const SourcePluginManifest({
    required this.id,
    required this.name,
    required this.version,
    required this.apiVersion,
    required this.entry,
    this.presentation = const {},
    this.translation = const {},
  });

  factory SourcePluginManifest.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final version = json['version'];
    final entry = json['entry'];
    if (id is! String ||
        !RegExp(r'^[a-z][a-z0-9_.-]{0,63}$').hasMatch(id) ||
        name is! String ||
        name.trim().isEmpty ||
        version is! String ||
        version.trim().isEmpty ||
        entry is! String ||
        !isPluginPath(entry) ||
        !entry.endsWith('.js')) {
      throw const SourcePluginException('plugin_invalid_manifest');
    }
    if (json['apiVersion'] != null && json['apiVersion'] != 1) {
      throw const SourcePluginException('plugin_unsupported_api');
    }
    final presentation = json['presentation'] is Map
        ? Map<String, dynamic>.from(json['presentation'] as Map)
        : const <String, dynamic>{};
    DirectComicIdRules.parse(presentation['directComicIdRules']);
    DailyRecommendationConfig.parse(presentation['dailyRecommendation']);
    if (presentation.containsKey('showComments') &&
        presentation['showComments'] is! bool) {
      throw const SourcePluginException('plugin_invalid_manifest');
    }
    final commentOrders = presentation['commentOrders'];
    if ((commentOrders != null &&
            (commentOrders is! Map ||
                commentOrders.entries.any(
                  (entry) =>
                      entry.key is! String ||
                      (entry.key as String).trim().isEmpty ||
                      entry.key != (entry.key as String).trim() ||
                      (entry.value is! String &&
                          (entry.value is! Map ||
                              (entry.value as Map).entries.any(
                                (label) =>
                                    label.key is! String ||
                                    label.value is! String,
                              ))),
                ))) ||
        (presentation['commentDefaultOrder'] != null &&
            presentation['commentDefaultOrder'] is! String)) {
      throw const SourcePluginException('plugin_invalid_manifest');
    }
    final groups = presentation['listTagGroups'];
    final enrich = presentation['enrichMissingTags'];
    final aliases = presentation['favoriteOrderAliases'];
    final orderLabels = presentation['favoriteOrderLabels'];
    final localOrders = presentation['localFavoriteOrders'];
    if (orderLabels != null &&
        (orderLabels is! Map ||
            orderLabels.entries.any(
              (entry) =>
                  entry.key is! String ||
                  (entry.value is! String &&
                      (entry.value is! Map ||
                          (entry.value as Map).entries.any(
                            (label) =>
                                label.key is! String || label.value is! String,
                          ))),
            ))) {
      throw const SourcePluginException('plugin_invalid_manifest');
    }
    if ((groups != null &&
            (groups is! List ||
                groups.any(
                  (value) => value is! String || value.trim().isEmpty,
                ))) ||
        (enrich != null && enrich is! bool) ||
        (aliases != null &&
            (aliases is! Map ||
                aliases.entries.any(
                  (entry) => entry.key is! String || entry.value is! String,
                )))) {
      throw const SourcePluginException('plugin_invalid_manifest');
    }
    if (localOrders != null &&
        (localOrders is! Map ||
            localOrders.entries.any(
              (entry) =>
                  entry.key is! String ||
                  !const [
                    'savedNewest',
                    'savedOldest',
                    'updatedNewest',
                  ].contains(entry.value),
            ))) {
      throw const SourcePluginException('plugin_invalid_manifest');
    }
    SourcePluginAction.parseList(presentation['actions']);
    SourcePluginButton.parseList(presentation['buttons']);
    if (json['settings'] case final Map settings) {
      for (final spec in settings.values.whereType<Map>()) {
        sourcePluginSettingLocation(spec['location']);
      }
    }
    return SourcePluginManifest(
      id: id,
      name: name,
      version: version,
      apiVersion: 1,
      entry: entry,
      presentation: presentation,
      translation: json['translation'] is Map
          ? Map<String, dynamic>.from(json['translation'] as Map)
          : const {},
    );
  }

  final String id;
  final String name;
  final String version;
  final int apiVersion;
  final String entry;
  final Map<String, dynamic> presentation;
  final Map<String, dynamic> translation;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'version': version,
    'apiVersion': apiVersion,
    'entry': entry,
    'presentation': presentation,
    if (translation.isNotEmpty) 'translation': translation,
  };
}

bool isPluginPath(String value) =>
    value.isNotEmpty &&
    !value.contains('\\') &&
    !value.contains(':') &&
    !value.contains('\u0000') &&
    !value.startsWith('/') &&
    value
        .split('/')
        .every(
          (part) =>
              part.isNotEmpty &&
              part != '.' &&
              part != '..' &&
              !part.endsWith('.') &&
              !part.endsWith(' ') &&
              !RegExp(r'[<>"|?*\x00-\x1f]').hasMatch(part) &&
              !RegExp(
                r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)',
                caseSensitive: false,
              ).hasMatch(part),
        );

bool isPluginVersion(String value) => RegExp(
  r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$',
).hasMatch(value);

int comparePluginVersions(String a, String b) {
  if (!isPluginVersion(a) || !isPluginVersion(b)) {
    throw const SourcePluginException('plugin_invalid_version');
  }
  final left = a.split('+').first.split('-');
  final right = b.split('+').first.split('-');
  final l = left.first.split('.').map(int.parse).toList();
  final r = right.first.split('.').map(int.parse).toList();
  for (var i = 0; i < 3; i++) {
    final result = l[i].compareTo(r[i]);
    if (result != 0) return result;
  }
  final lp = left.skip(1).join('-');
  final rp = right.skip(1).join('-');
  if (lp == rp) return 0;
  if (lp.isEmpty) return 1;
  if (rp.isEmpty) return -1;
  final li = lp.split('.');
  final ri = rp.split('.');
  for (var i = 0; i < li.length && i < ri.length; i++) {
    if (li[i] == ri[i]) continue;
    final ln = int.tryParse(li[i]);
    final rn = int.tryParse(ri[i]);
    if (ln != null && rn != null) return ln.compareTo(rn);
    if (ln != null) return -1;
    if (rn != null) return 1;
    return li[i].compareTo(ri[i]);
  }
  return li.length.compareTo(ri.length);
}

class SourcePluginIndexEntry {
  const SourcePluginIndexEntry({
    required this.id,
    required this.name,
    required this.version,
    required this.downloadUrl,
  });
  final String id;
  final String name;
  final String version;
  final Uri downloadUrl;
}

List<SourcePluginIndexEntry> parsePluginIndex(String content) {
  final decoded = jsonDecode(content);
  if (decoded is! Map ||
      decoded['schemaVersion'] != 1 ||
      decoded['plugins'] is! List) {
    throw const SourcePluginException('plugin_invalid_index');
  }
  final ids = <String>{};
  return (decoded['plugins'] as List)
      .map((item) {
        if (item is! Map) {
          throw const SourcePluginException('plugin_invalid_index');
        }
        final map = Map<String, dynamic>.from(item);
        final manifest = SourcePluginManifest.fromJson({
          ...map,
          'apiVersion': 1,
          'entry': 'main.js',
        });
        if (!isPluginVersion(manifest.version)) {
          throw const SourcePluginException('plugin_invalid_index');
        }
        final url = Uri.tryParse(map['downloadUrl']?.toString() ?? '');
        if (!ids.add(manifest.id) ||
            url == null ||
            url.scheme != 'https' ||
            url.host.isEmpty ||
            url.userInfo.isNotEmpty) {
          throw const SourcePluginException('plugin_invalid_index');
        }
        return SourcePluginIndexEntry(
          id: manifest.id,
          name: manifest.name,
          version: manifest.version,
          downloadUrl: url,
        );
      })
      .toList(growable: false);
}

class SourcePluginUpdate {
  const SourcePluginUpdate({
    required this.plugin,
    required this.entry,
    required this.localVersion,
  });

  final InstalledSourcePlugin plugin;
  final SourcePluginIndexEntry entry;
  final String localVersion;
}

class InstalledSourcePlugin {
  const InstalledSourcePlugin({
    required this.manifest,
    required this.directory,
    this.repository,
    this.enabled = true,
    this.customEdited = false,
    this.editBackup,
  });
  final SourcePluginManifest manifest;

  /// A relative, generated directory name inside the plugin store.
  final String directory;
  final String? repository;
  final bool enabled;
  final bool customEdited;
  final SourcePluginScriptBackup? editBackup;

  InstalledSourcePlugin copyWith({
    bool? enabled,
    bool? customEdited,
    String? directory,
    SourcePluginScriptBackup? editBackup,
  }) => InstalledSourcePlugin(
    manifest: manifest,
    directory: directory ?? this.directory,
    repository: repository,
    enabled: enabled ?? this.enabled,
    customEdited: customEdited ?? this.customEdited,
    editBackup: editBackup ?? this.editBackup,
  );

  Map<String, dynamic> toJson() => {
    'manifest': manifest.toJson(),
    'directory': directory,
    'repository': repository,
    'enabled': enabled,
    'customEdited': customEdited,
    if (editBackup != null) 'editBackup': editBackup!.toJson(),
  };

  factory InstalledSourcePlugin.fromJson(Map<String, dynamic> map) {
    final directory = map['directory'];
    if (directory is! String || !isPluginPath(directory)) {
      throw const SourcePluginException('plugin_invalid_store');
    }
    return InstalledSourcePlugin(
      manifest: SourcePluginManifest.fromJson(
        Map<String, dynamic>.from(map['manifest'] as Map),
      ),
      directory: directory,
      repository: map['repository'] as String?,
      enabled: map['enabled'] == true,
      customEdited: map['customEdited'] == true,
      editBackup: map['editBackup'] is Map
          ? SourcePluginScriptBackup.fromJson(
              Map<String, dynamic>.from(map['editBackup'] as Map),
            )
          : null,
    );
  }
}

/// A single previous saved script, without recursively retaining older backups.
class SourcePluginScriptBackup {
  const SourcePluginScriptBackup({
    required this.manifest,
    required this.directory,
    required this.customEdited,
  });

  final SourcePluginManifest manifest;
  final String directory;
  final bool customEdited;

  Map<String, dynamic> toJson() => {
    'manifest': manifest.toJson(),
    'directory': directory,
    'customEdited': customEdited,
  };

  factory SourcePluginScriptBackup.fromJson(Map<String, dynamic> json) {
    final plugin = InstalledSourcePlugin.fromJson(json);
    return SourcePluginScriptBackup(
      manifest: plugin.manifest,
      directory: plugin.directory,
      customEdited: plugin.customEdited,
    );
  }
}
