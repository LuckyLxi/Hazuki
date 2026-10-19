import 'dart:convert';

import 'source_script_engine.dart';
import 'source_runtime_metadata.dart';

import '../../../models/source_meta.dart';
import '../models/source_contract_models.dart';
import '../common/source_json_coerce.dart';

class SourceRuntimeKernel {
  SourceRuntimeKernel({
    Future<dynamic> Function(Future<dynamic> Function())? operationGuard,
    this.onMetadataChanged,
  }) : _operationGuard = operationGuard;
  final void Function()? onMetadataChanged;
  final Future<dynamic> Function(Future<dynamic> Function())? _operationGuard;
  SourceScriptEngine? _engine;
  SourceScriptEngine? get engine => _engine;
  set engine(SourceScriptEngine? value) {
    _engine = value;
    value?.operationGuard = _operationGuard;
    // A candidate is published with metadata from this same snapshot. Do not
    // notify again on its first operation when nothing actually changed.
    _metadataJson = value?.cachedValue('__metadata') as String?;
    if (value != null) {
      value.onSnapshotChanged = () {
        if (!identical(value, _engine)) return;
        final json = value.cachedValue('__metadata');
        final previous = sourceMeta;
        if (previous == null || json is! String || json == _metadataJson) {
          return;
        }
        final data = jsonDecode(json) as Map;
        if (data['key'] != previous.key) return;
        final settings = jsAsMap(data['settings']);
        sourceMeta = SourceMeta(
          name: data['name']?.toString() ?? previous.name,
          key: previous.key,
          version: data['version']?.toString() ?? previous.version,
          supportsAccount: data['supportsAccount'] == true,
          settingsDefaults: parseSourceSettingsDefaults(settings),
          settings: settings,
          presentation: jsAsMap(data['presentation']),
          translation: jsAsMap(data['translation']),
        );
        _metadataJson = json;
        onMetadataChanged?.call();
      };
    }
  }

  String? _metadataJson;
  Future<void>? initFuture;
  String statusText = 'source_idle';
  SourceRuntimeState runtimeState = const SourceRuntimeState.idle();
  SourceMeta? sourceMeta;
  bool isRefreshingSource = false;
  DateTime? lastReloginAt;
  String? transientAvatarUrl;

  bool shouldSkipRelogin(Duration minInterval) {
    final last = lastReloginAt;
    return last != null && DateTime.now().difference(last) < minInterval;
  }
}
