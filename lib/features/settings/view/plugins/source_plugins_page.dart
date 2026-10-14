import 'dart:async';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/widgets/widgets.dart';
import 'source_plugin_settings_page.dart';

class SourcePluginsPage extends StatefulWidget {
  const SourcePluginsPage({super.key, required this.manager});
  final SourcePluginGateway manager;
  @override
  State<SourcePluginsPage> createState() => _SourcePluginsPageState();
}

class _SourcePluginsPageState extends State<SourcePluginsPage> {
  late final SourcePluginGateway _manager;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _manager = widget.manager;
    unawaited(_run(_manager.initialize));
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
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

  Future<void> _addRepository() async {
    final address = TextEditingController();
    final branch = TextEditingController();
    final path = TextEditingController(text: 'plugins.json');
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          final s = l10n(context);
          return AlertDialog(
            title: Text(s.pluginsAddRepository),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: address,
                    decoration: InputDecoration(
                      labelText: s.pluginsRepositoryUrl,
                    ),
                  ),
                  TextField(
                    controller: branch,
                    decoration: InputDecoration(labelText: s.pluginsBranch),
                  ),
                  TextField(
                    controller: path,
                    decoration: InputDecoration(labelText: s.pluginsIndexPath),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(s.commonCancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(s.commonConfirm),
              ),
            ],
          );
        },
      );
      if (confirmed == true) {
        await _manager.addRepository(
          address.text,
          branch: branch.text.trim().isEmpty ? null : branch.text.trim(),
          path: path.text.trim(),
        );
      }
    } finally {
      address.dispose();
      branch.dispose();
      path.dispose();
    }
  }

  Future<void> _update(String id) async {
    final update = await _manager.checkUpdate(id);
    if (update == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n(context).pluginsNoUpdate)));
      }
      return;
    }
    final plugin = _manager.pluginFor(id)!;
    await _installFromRepository(plugin.repository!, update);
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
    return Scaffold(
      appBar: hazukiFrostedAppBar(
        context: context,
        title: Text(s.pluginsTitle),
      ),
      body: AnimatedBuilder(
        animation: _manager,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _busy ? null : () => _run(_import),
                  icon: const Icon(Icons.file_open_outlined),
                  label: Text(s.pluginsImportLocal),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _run(_addRepository),
                  icon: const Icon(Icons.add_link),
                  label: Text(s.pluginsAddRepository),
                ),
              ],
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: LinearProgressIndicator(),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: SelectableText(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 24),
            Text(
              s.pluginsInstalled,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (_manager.installed.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(s.pluginsEmpty),
              ),
            for (final plugin in _manager.installed)
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: Text(plugin.manifest.name),
                      subtitle: Text(
                        '${plugin.manifest.version} · ${plugin.manifest.id}\n${plugin.repository ?? s.pluginsLocalPackage}',
                      ),
                      value: plugin.enabled,
                      onChanged: _busy
                          ? null
                          : (value) => _run(
                              () => _manager.setEnabled(
                                plugin.manifest.id,
                                value,
                              ),
                            ),
                    ),
                    if (_manager.errors[plugin.manifest.id] case final error?)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(error),
                      ),
                    Wrap(
                      spacing: 12,
                      children: [
                        if (plugin.repository != null)
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => _run(() => _update(plugin.manifest.id)),
                            child: Text(s.pluginsCheckUpdate),
                          ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => _run(
                                  () => _manager.uninstall(plugin.manifest.id),
                                ),
                          child: Text(s.pluginsUninstall),
                        ),
                        TextButton(
                          onPressed: _busy || !plugin.enabled
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
                          child: Text(s.settingsTitle),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            Text(
              s.pluginsRepositories,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            for (final repository in _manager.repositories)
              Card(
                child: ExpansionTile(
                  title: Text(repository),
                  onExpansionChanged: (expanded) {
                    if (expanded && !_busy) {
                      unawaited(
                        _run(() => _manager.refreshRepository(repository)),
                      );
                    }
                  },
                  children: [
                    Wrap(
                      spacing: 12,
                      children: [
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => _run(
                                  () => _manager.refreshRepository(repository),
                                ),
                          child: Text(s.pluginsRefresh),
                        ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => _run(
                                  () => _manager.removeRepository(repository),
                                ),
                          child: Text(s.pluginsRemoveRepository),
                        ),
                      ],
                    ),
                    for (final entry in _manager.entriesFor(repository))
                      ListTile(
                        title: Text(entry.name),
                        subtitle: Text(entry.version),
                        trailing: TextButton(
                          onPressed: _busy
                              ? null
                              : () => _run(
                                  () =>
                                      _installFromRepository(repository, entry),
                                ),
                          child: Text(s.pluginsInstall),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
