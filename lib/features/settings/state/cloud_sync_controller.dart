import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:hazuki/services/cloud_sync_service.dart';

typedef ApplyCloudSyncRestoreCallback =
    Future<void> Function(CloudSyncRestoreResult result);

/// 正在执行的备份动作，供页面在对应条目上展示进度。
enum CloudSyncAction { upload, restore }

class CloudSyncRestoreOutcome {
  const CloudSyncRestoreOutcome({required this.skippedPlatformSettings});
  final bool skippedPlatformSettings;
}

class CloudSyncController extends ChangeNotifier {
  CloudSyncController({required CloudSyncService service}) : _service = service;

  final CloudSyncService _service;

  final TextEditingController urlController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool _enabled = false;
  bool _loading = true;
  bool _saving = false;
  bool _syncing = false;
  bool _checkingConnectivity = false;
  CloudSyncAction? _activeAction;
  CloudSyncConnectionStatus? _status;
  bool _disposed = false;

  bool get enabled => _enabled;
  bool get loading => _loading;
  bool get saving => _saving;
  bool get syncing => _syncing;
  bool get checkingConnectivity => _checkingConnectivity;
  CloudSyncAction? get activeAction => _activeAction;
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

  /// 用当前输入的配置重新检测连接状态。
  Future<void> testConnection() => _checkConnectivityOnce(_buildConfig());

  /// 由服务器编辑表单提交：写回输入框后保存并检测连接。
  Future<void> saveServerConfig({
    required String url,
    required String username,
    required String password,
  }) {
    urlController.text = url;
    usernameController.text = username;
    passwordController.text = password;
    return saveConfig();
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
    _activeAction = CloudSyncAction.upload;
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
        _activeAction = null;
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
    _activeAction = CloudSyncAction.restore;
    _notify();
    try {
      final config = _buildConfig();
      await _service.saveConfig(config);
      final result = await _service.restoreLatestBackup(configOverride: config);
      await applyRestore(result);
      final status = await _service.testConnection(configOverride: config);
      if (!_disposed) {
        _status = status;
      }
      return CloudSyncRestoreOutcome(
        skippedPlatformSettings: result.skippedKeys.isNotEmpty,
      );
    } finally {
      if (!_disposed) {
        _syncing = false;
        _activeAction = null;
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
