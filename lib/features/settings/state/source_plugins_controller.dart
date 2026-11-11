import 'package:flutter/foundation.dart';
import 'package:hazuki/services/source/source_capabilities.dart';

enum PluginOperationPage { installed, available }

class SourcePluginsController extends ChangeNotifier {
  SourcePluginsController(this._manager);

  final SourcePluginGateway _manager;
  PluginOperationPage? _busyPage;
  final Set<String> _installing = {};
  final Map<String, bool> _pendingEnabled = {};
  bool _sorting = false;
  List<String>? _sortOrder;
  bool _disposed = false;

  PluginOperationPage? get busyPage => _busyPage;
  bool get hasOperations => _busyPage != null || _installing.isNotEmpty;
  bool get sorting => _sorting;
  bool isInstalling(String id) => _installing.contains(id);
  bool isChangingEnabled(String id) => _pendingEnabled.containsKey(id);
  bool enabledFor(InstalledSourcePlugin plugin) =>
      _pendingEnabled[plugin.manifest.id] ?? plugin.enabled;

  Future<void> run(
    Future<void> Function() action, {
    String? pluginId,
    PluginOperationPage page = PluginOperationPage.installed,
  }) async {
    if (_disposed ||
        _busyPage != null ||
        (pluginId == null
            ? _installing.isNotEmpty
            : _installing.contains(pluginId))) {
      return;
    }
    if (pluginId == null) {
      _busyPage = page;
    } else {
      _installing.add(pluginId);
    }
    _notify();
    try {
      await action();
    } finally {
      if (pluginId == null) {
        _busyPage = null;
      } else {
        _installing.remove(pluginId);
      }
      _notify();
    }
  }

  Future<void> setEnabled(String id, bool enabled) async {
    if (_disposed || hasOperations || isChangingEnabled(id)) return;
    _pendingEnabled[id] = enabled;
    _notify();
    try {
      await _manager.setEnabled(id, enabled);
    } finally {
      _pendingEnabled.remove(id);
      _notify();
    }
  }

  List<InstalledSourcePlugin> get sortedInstalled {
    final installed = _manager.installed;
    final order = _sortOrder;
    if (order == null) return installed;
    final byId = {for (final plugin in installed) plugin.manifest.id: plugin};
    return [
      for (final id in order) ?byId[id],
      for (final plugin in installed)
        if (!order.contains(plugin.manifest.id)) plugin,
    ];
  }

  Future<void> movePlugin(int oldIndex, int newIndex) async {
    if (_disposed || oldIndex == newIndex) return;
    final ids = [for (final plugin in sortedInstalled) plugin.manifest.id];
    ids.insert(newIndex, ids.removeAt(oldIndex));
    _sortOrder = ids;
    _notify();
    try {
      await _manager.reorder(ids);
    } catch (_) {
      _sortOrder = null;
      _notify();
      rethrow;
    }
  }

  void setSorting(bool sorting) {
    if (_disposed) return;
    _sorting = sorting;
    _sortOrder = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
