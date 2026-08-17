import 'dart:io';

import '../common/source_prefs_keys.dart';
import '../models/source_identity.dart';
import 'source_runtime_facade.dart';
import 'source_runtime_handle.dart';
import 'source_runtime_host.dart';
import 'source_runtime_state_controller.dart';
import 'source_script_storage.dart';

/// Owns local source-script editing and edit-state lifecycle.
///
/// Runtime initialization only provides the callback that ensures an editable
/// script exists. File operations and restart-state transitions stay here.
class SourceScriptEditingOperations {
  SourceScriptEditingOperations({
    required SourceRuntimeHost runtimeHost,
    required SourceScriptStore storage,
    required SourceRuntimeStateController runtimeStateController,
    required Future<File> Function(SourceRuntimeHandle handle)
    ensureEditableFile,
  }) : _runtimeHost = runtimeHost,
       _storage = storage,
       _runtimeStateController = runtimeStateController,
       _ensureEditableFile = ensureEditableFile;

  final SourceRuntimeHost _runtimeHost;
  final SourceScriptStore _storage;
  final SourceRuntimeStateController _runtimeStateController;
  final Future<File> Function(SourceRuntimeHandle handle) _ensureEditableFile;

  String get _activeSourceKey => _runtimeHost.activeSourceKey;

  Future<String?> readLocalActiveSourceIfExists() =>
      _storage.readIfExists(_activeSourceKey);

  Future<String> loadEditableActiveSource() =>
      loadEditableSource(_activeSourceKey);

  Future<String> loadEditableSource(String sourceKey) async {
    final handle = _runtimeHost.handleFor(sourceKey);
    return handle.runOperation(() async {
      final file = await _ensureEditableFile(handle);
      return file.readAsString();
    });
  }

  Future<void> writeLocalActiveSource(String content) =>
      writeLocalSource(_activeSourceKey, content);

  Future<void> writeLocalSource(String sourceKey, String content) async {
    final normalizedSourceKey = _runtimeHost.normalize(sourceKey);
    await _storage.write(normalizedSourceKey, content);
    await setCustomEditedSourceFlag(normalizedSourceKey, true);
  }

  Future<void> saveEditedActiveSource(String content) =>
      saveEditedSource(_activeSourceKey, content);

  Future<void> saveEditedSource(String sourceKey, String content) async {
    final handle = _runtimeHost.handleFor(sourceKey);
    await handle.runOperation(() async {
      final facade = handle.facade;
      await _ensureEditableFile(handle);
      await _storage.write(handle.sourceKey, content);
      await setCustomEditedSourceFlag(
        handle.sourceKey,
        true,
        targetFacade: facade,
      );
      facade.lastSourceVersionDebugInfo = {
        'checkedAt': DateTime.now().toIso8601String(),
        'resolvedFrom': 'local_source_editor',
        'sourceKey': handle.sourceKey,
        'outcome': 'edited_waiting_for_restart',
      };
      _runtimeStateController.setWaitingForRestart(
        facade,
        statusText: 'source_edited_waiting_for_restart',
        debugDetail: 'local_source_editor',
      );
    });
  }

  Future<bool> hasLocalActiveSourceFile() => _storage.exists(_activeSourceKey);

  Future<bool> hasLocalSourceFile(String sourceKey) =>
      _storage.exists(sourceKey);

  Future<void> deleteLocalSourceFile(String sourceKey) async {
    final normalizedSourceKey = _runtimeHost.normalize(sourceKey);
    if (normalizedSourceKey == _activeSourceKey) {
      throw StateError('source_delete_active_not_allowed');
    }

    await _storage.delete(normalizedSourceKey);
    await setCustomEditedSourceFlag(normalizedSourceKey, false);
    _runtimeHost.remove(normalizedSourceKey);
  }

  Future<bool> hasCustomEditedActiveSource() =>
      hasCustomEditedSource(_activeSourceKey);

  Future<bool> hasCustomEditedSource(String sourceKey) =>
      _storage.isCustomEdited(sourceKey);

  Future<void> setCustomEditedSourceFlag(
    String sourceKey,
    bool value, {
    HazukiSourceFacade? targetFacade,
  }) async {
    final normalizedSourceKey = _runtimeHost.normalize(sourceKey);
    if (targetFacade == null) {
      await _storage.setCustomEdited(normalizedSourceKey, value);
      return;
    }
    final prefs = await targetFacade.ensurePrefs();
    await prefs.setBool(
      SourcePrefsKeys.customEditedSource(normalizedSourceKey),
      value,
    );
    if (normalizedSourceKey == hazukiDefaultSourceKey) {
      await prefs.setBool(SourcePrefsKeys.customEditedJmSource, value);
    }
  }
}
