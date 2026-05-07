import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:hazuki/app/hazuki_app_controller.dart';
import 'package:hazuki/services/cloud_sync_service.dart';

typedef ApplyCloudSyncRestoreCallback =
    Future<CloudSyncRestoreApplyResult> Function(CloudSyncRestoreResult result);

class CloudSyncRestoreOutcome {
  const CloudSyncRestoreOutcome({
    required this.skippedPlatformSettings,
    required this.sourceNeedsRestart,
  });
  final bool skippedPlatformSettings;
  final bool sourceNeedsRestart;
}

class CloudSyncController extends ChangeNotifier {
  CloudSyncController({CloudSyncService? service})
    : _service = service ?? CloudSyncService.instance;

  final CloudSyncService _service;

  final TextEditingController urlController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool _enabled = false;
  bool _loading = true;
  bool _saving = false;
  bool _syncing = false;
  bool _checkingConnectivity = false;
  CloudSyncConnectionStatus? _status;
  bool _disposed = false;

  bool get enabled => _enabled;
  bool get loading => _loading;
  bool get saving => _saving;
  bool get syncing => _syncing;
  bool get checkingConnectivity => _checkingConnectivity;
  CloudSyncConnectionStatus? get status => _status;

  bool get isConfigComplete => _buildConfig().isComplete;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  CloudSyncConfig _buildConfig() {
    return CloudSyncConfig(
      enabled: _enabled,
      url: urlController.text.trim(),
      username: usernameController.text.trim(),
      password: passwordController.text,
    );
  }

  Future<void> loadConfig() async {
    final config = await _service.loadConfig();
    if (_disposed) return;
    _enabled = config.enabled;
    urlController.text = config.url;
    usernameController.text = config.username;
    passwordController.text = config.password;
    _loading = false;
    _status = null;
    _notify();
    if (config.enabled && config.isComplete) {
      unawaited(_checkConnectivityOnce(config));
    }
  }

  Future<void> _checkConnectivityOnce(CloudSyncConfig config) async {
    if (_disposed || _checkingConnectivity) return;
    _checkingConnectivity = true;
    _notify();
    try {
      final status = await _service.testConnection(configOverride: config);
      if (_disposed) return;
      _status = status;
    } finally {
      if (!_disposed) {
        _checkingConnectivity = false;
        _notify();
      }
    }
  }

  void setEnabled(bool value) {
    _enabled = value;
    if (!value) {
      _status = null;
    }
    _notify();
    unawaited(_service.saveConfig(_buildConfig()));
  }

  Future<void> saveConfig() async {
    if (_disposed || _saving) return;
    _saving = true;
    _notify();
    try {
      final config = _buildConfig();
      await _service.saveConfig(config);
      if (config.enabled && config.isComplete) {
        final status = await _service.testConnection(configOverride: config);
        if (_disposed) return;
        _status = status;
      } else {
        _status = null;
      }
    } finally {
      if (!_disposed) {
        _saving = false;
        _notify();
      }
    }
  }

  Future<void> uploadBackup() async {
    if (_disposed || _syncing) return;
    _syncing = true;
    _notify();
    try {
      final config = _buildConfig();
      await _service.uploadBackup(configOverride: config);
      final status = await _service.testConnection(configOverride: config);
      if (_disposed) return;
      _status = status;
    } finally {
      if (!_disposed) {
        _syncing = false;
        _notify();
      }
    }
  }

  Future<CloudSyncRestoreOutcome> restoreBackup({
    required ApplyCloudSyncRestoreCallback applyRestore,
  }) async {
    if (_syncing) {
      throw StateError('cloud sync busy');
    }
    _syncing = true;
    _notify();
    try {
      final config = _buildConfig();
      final result = await _service.restoreLatestBackup(configOverride: config);
      final applyResult = await applyRestore(result);
      final status = await _service.testConnection(configOverride: config);
      if (!_disposed) {
        _status = status;
      }
      return CloudSyncRestoreOutcome(
        skippedPlatformSettings: result.skippedKeys.isNotEmpty,
        sourceNeedsRestart: applyResult.sourceNeedsRestart,
      );
    } finally {
      if (!_disposed) {
        _syncing = false;
        _notify();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    urlController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
