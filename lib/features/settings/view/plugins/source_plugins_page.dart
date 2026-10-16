import 'dart:async';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/services/source/plugins/source_plugin_repository.dart';

import 'package:hazuki/widgets/widgets.dart';
import 'source_plugin_settings_page.dart';

part 'source_plugins_widgets.dart';

enum _PluginOperationPage { installed, available }

enum SourcePluginsTab { installed, market }

class SourcePluginsPage extends StatefulWidget {
  const SourcePluginsPage({
    super.key,
    required this.manager,
    this.initialTab = SourcePluginsTab.installed,
  });
  final SourcePluginGateway manager;
  final SourcePluginsTab initialTab;
  @override
  State<SourcePluginsPage> createState() => _SourcePluginsPageState();
}

class _SourcePluginsPageState extends State<SourcePluginsPage> {
  late final SourcePluginGateway _manager;
  _PluginOperationPage? _busyPage;
  bool get _busy => _busyPage != null;
  final Set<String> _installing = {};
  final Map<String, bool> _pendingEnabled = {};
  bool get _hasOperations => _busy || _installing.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _manager = widget.manager;
    unawaited(_run(_manager.initialize));
  }

  Future<void> _run(
    Future<void> Function() action, {
    String? pluginId,
    _PluginOperationPage page = _PluginOperationPage.installed,
  }) async {
    if (_busy ||
        (pluginId == null
            ? _installing.isNotEmpty
            : _installing.contains(pluginId))) {
      return;
    }
    setState(() {
      if (pluginId == null) {
        _busyPage = page;
      } else {
        _installing.add(pluginId);
      }
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        unawaited(showHazukiPrompt(context, error.toString(), isError: true));
      }
    } finally {
      if (mounted) {
        setState(() {
          if (pluginId == null) {
            _busyPage = null;
          } else {
            _installing.remove(pluginId);
          }
        });
      }
    }
  }

  Future<void> _import() async {
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(label: 'JavaScript', extensions: ['js']),
      ],
    );
    if (file != null) await _manager.importPackage(await file.readAsBytes());
  }

  Future<void> _setEnabled(String id, bool enabled) async {
    if (_hasOperations || _pendingEnabled.containsKey(id)) return;
    setState(() => _pendingEnabled[id] = enabled);
    try {
      await _manager.setEnabled(id, enabled);
    } catch (error) {
      if (mounted) {
        unawaited(showHazukiPrompt(context, error.toString(), isError: true));
      }
    } finally {
      if (mounted) setState(() => _pendingEnabled.remove(id));
    }
  }

  Future<void> _update(String id) async {
    final update = await _manager.checkUpdate(id);
    if (update == null) {
      if (mounted) {
        unawaited(showHazukiPrompt(context, l10n(context).pluginsNoUpdate));
      }
      return;
    }
    final plugin = _manager.pluginFor(id)!;
    await _installFromRepository(
      plugin.repository ?? sourcePluginsRepositoryUrl,
      update,
    );
  }

  Future<void> _confirmUninstall(InstalledSourcePlugin plugin) async {
    final s = l10n(context);
    final confirmed = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final colors = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: Text(s.pluginsUninstallTitle),
          content: Text(s.pluginsUninstallConfirm(plugin.manifest.name)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(s.commonCancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(s.commonConfirm),
            ),
          ],
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: animation.drive(
              Tween<double>(
                begin: 0.9,
                end: 1.0,
              ).chain(CurveTween(curve: Curves.easeOutCubic)),
            ),
            child: child,
          ),
        );
      },
    );
    if (confirmed != true || !mounted) return;
    await _run(() => _manager.uninstall(plugin.manifest.id));
  }

  Future<void> _installFromRepository(
    String repository,
    SourcePluginIndexEntry entry,
  ) async {
    if (_manager.pluginFor(entry.id)?.customEdited == true) {
      if (!mounted) return;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(l10n(context).pluginsEditedUpdate),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n(context).commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n(context).commonConfirm),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }
    await _manager.installFromRepository(repository, entry);
  }

  @override
  Widget build(BuildContext context) {
    final s = l10n(context);
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab.index,
      child: Scaffold(
        appBar: hazukiFrostedAppBar(
          context: context,
          title: Text(s.pluginsTitle),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: s.pluginsInstalled),
              Tab(text: s.pluginsAvailable),
            ],
          ),
        ),
        body: SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: AnimatedBuilder(
                animation: _manager,
                builder: (context, _) => TabBarView(
                  children: [
                    ListView(
                      key: const PageStorageKey('installed-plugins'),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      children: [
                        _overview(context),
                        if (_busyPage == _PluginOperationPage.installed)
                          const Padding(
                            padding: EdgeInsets.only(top: 16),
                            child: LinearProgressIndicator(),
                          ),
                        const SizedBox(height: 28),
                        _PluginSectionHeader(
                          title: s.pluginsInstalled,
                          count: _manager.installed.length,
                        ),
                        const SizedBox(height: 12),
                        if (_manager.installed.isEmpty)
                          _PluginEmptyState(
                            icon: Icons.extension_outlined,
                            message: s.pluginsEmpty,
                          )
                        else
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final width = constraints.maxWidth >= 800
                                  ? (constraints.maxWidth - 16) / 2
                                  : constraints.maxWidth;
                              return Wrap(
                                spacing: 16,
                                runSpacing: 16,
                                children: [
                                  for (final plugin in _manager.installed)
                                    SizedBox(
                                      width: width,
                                      child: _installedCard(context, plugin),
                                    ),
                                ],
                              );
                            },
                          ),
                      ],
                    ),
                    ListView(
                      key: const PageStorageKey('available-plugins'),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      children: [
                        if (_busyPage == _PluginOperationPage.available ||
                            _manager.checkingIndex) ...[
                          const LinearProgressIndicator(),
                          const SizedBox(height: 12),
                        ],
                        if (_manager.indexError case final error?) ...[
                          _PluginError(message: error),
                          const SizedBox(height: 12),
                        ],
                        _repositoryCard(context, sourcePluginsRepositoryUrl),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _overview(BuildContext context) {
    final s = l10n(context);
    final theme = Theme.of(context);
    return _PluginSurface(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.extension_rounded,
              size: 32,
              color: theme.colorScheme.onPrimaryContainer,
            ),
            const SizedBox(height: 12),
            Text(
              s.pluginsSubtitle,
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PluginBadge(
                  label: '${s.pluginsInstalled} · ${_manager.installed.length}',
                ),
                _PluginBadge(
                  label:
                      '${s.pluginsEnabled} · ${_manager.installed.where((plugin) => plugin.enabled).length}',
                ),
                _PluginBadge(
                  label:
                      '${s.pluginsAvailable} · ${_manager.entriesFor(sourcePluginsRepositoryUrl).length}',
                ),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _hasOperations ? null : () => _run(_import),
                  icon: const Icon(Icons.file_open_outlined),
                  label: Text(s.pluginsImportLocal),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _installedCard(BuildContext context, InstalledSourcePlugin plugin) {
    final s = l10n(context);
    final theme = Theme.of(context);
    return _PluginSurface(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _PluginIcon(
                  icon: Icons.extension_outlined,
                  highlighted: plugin.enabled,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plugin.manifest.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        plugin.manifest.id,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Semantics(
                  label: plugin.manifest.name,
                  child: Switch(
                    value:
                        _pendingEnabled[plugin.manifest.id] ?? plugin.enabled,
                    onChanged:
                        _hasOperations ||
                            _pendingEnabled.containsKey(plugin.manifest.id)
                        ? null
                        : (value) => _setEnabled(plugin.manifest.id, value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PluginBadge(label: plugin.manifest.version),
                _PluginBadge(
                  label: plugin.enabled ? s.pluginsEnabled : s.pluginsDisabled,
                  highlighted: plugin.enabled,
                ),
                if (plugin.customEdited)
                  _PluginBadge(label: s.pluginsLocallyEdited),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  plugin.repository == null
                      ? Icons.insert_drive_file_outlined
                      : Icons.link,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    plugin.repository ?? s.pluginsLocalPackage,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            if (_manager.errors[plugin.manifest.id] case final error?) ...[
              const SizedBox(height: 12),
              _PluginError(message: error),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(height: 1),
            ),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                TextButton.icon(
                  onPressed: _hasOperations || !plugin.enabled
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => SourcePluginSettingsPage(
                              gateway: _manager,
                              id: plugin.manifest.id,
                            ),
                          ),
                        ),
                  icon: const Icon(Icons.tune, size: 18),
                  label: Text(s.settingsTitle),
                ),
                if (plugin.repository != null &&
                    (plugin.repository == sourcePluginsRepositoryUrl ||
                        _manager.repositories.contains(plugin.repository)))
                  TextButton.icon(
                    onPressed: _hasOperations
                        ? null
                        : () => _run(() => _update(plugin.manifest.id)),
                    icon: const Icon(Icons.update, size: 18),
                    label: Text(
                      _manager.availableUpdates.any(
                            (update) => update.entry.id == plugin.manifest.id,
                          )
                          ? s.pluginsUpdate
                          : s.pluginsCheckUpdate,
                    ),
                  ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  onPressed: _hasOperations
                      ? null
                      : () => _confirmUninstall(plugin),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: Text(s.pluginsUninstall),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _repositoryCard(BuildContext context, String repository) {
    final s = l10n(context);
    final theme = Theme.of(context);
    final entries = _manager.entriesFor(repository);
    return _PluginSurface(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              sourcePluginsRepositoryName,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: _hasOperations || _manager.checkingIndex
                    ? null
                    : () => _run(
                        () => _manager.refreshRepository(repository),
                        page: _PluginOperationPage.available,
                      ),
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(s.pluginsRefresh),
              ),
            ),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  s.pluginsRepositoryEmpty,
                  textAlign: TextAlign.center,
                ),
              ),
            for (final entry in entries) ...[
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.name, style: theme.textTheme.titleSmall),
                        Text(
                          '${entry.version} · ${entry.id}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.tonal(
                    key: ValueKey('plugin-market-action-${entry.id}'),
                    onPressed:
                        _busy ||
                            _installing.contains(entry.id) ||
                            _manager.checkingIndex ||
                            (_manager.pluginFor(entry.id) != null &&
                                !_manager.availableUpdates.any(
                                  (update) => update.entry.id == entry.id,
                                ))
                        ? null
                        : () => _run(
                            () => _installFromRepository(repository, entry),
                            pluginId: entry.id,
                          ),
                    child: _PluginOperationLabel(
                      loading: _installing.contains(entry.id),
                      loadingLabel: s.commonLoading,
                      label: _manager.pluginFor(entry.id) == null
                          ? s.pluginsInstall
                          : _manager.availableUpdates.any(
                              (update) => update.entry.id == entry.id,
                            )
                          ? s.pluginsUpdate
                          : s.pluginsAlreadyInstalled,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
