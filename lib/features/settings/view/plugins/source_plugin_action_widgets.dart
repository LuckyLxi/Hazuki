import 'package:flutter/material.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/services/source/plugins/source_plugin_localization.dart';

import '../settings_group.dart';

/// Shows declarations from enabled plugins without initializing their runtimes.
class SourcePluginActionList extends StatelessWidget {
  const SourcePluginActionList({
    super.key,
    required this.gateway,
    required this.location,
    this.pluginId,
  });

  final SourcePluginGateway gateway;
  final SourcePluginActionLocation location;
  final String? pluginId;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: gateway,
    builder: (context, _) {
      final tiles = <Widget>[];
      for (final plugin in gateway.installed.where(
        (plugin) =>
            plugin.enabled &&
            (pluginId == null || plugin.manifest.id == pluginId),
      )) {
        for (final action in SourcePluginAction.parseList(
          plugin.manifest.presentation['actions'],
        ).where((action) => action.location == location)) {
          tiles.add(
            SourcePluginActionTile(
              key: ValueKey((plugin.manifest.id, plugin.directory, action.id)),
              gateway: gateway,
              pluginId: plugin.manifest.id,
              pluginName: plugin.manifest.name,
              action: action,
              translation: plugin.manifest.translation,
            ),
          );
        }
      }
      return tiles.isEmpty
          ? const SizedBox.shrink()
          : SettingsGroup(children: tiles);
    },
  );
}

class SourcePluginActionTile extends StatefulWidget {
  const SourcePluginActionTile({
    super.key,
    required this.gateway,
    required this.pluginId,
    required this.action,
    this.pluginName,
    this.translation = const {},
  });

  final SourcePluginGateway gateway;
  final String pluginId;
  final String? pluginName;
  final SourcePluginAction action;
  final Map<String, dynamic> translation;

  @override
  State<SourcePluginActionTile> createState() => _SourcePluginActionTileState();
}

class _SourcePluginActionTileState extends State<SourcePluginActionTile> {
  bool _busy = false;
  String? _error;

  Future<void> _run() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.gateway.runAction(
        widget.pluginId,
        widget.action.id,
      );
      if (mounted && result != null) {
        final translation = widget.translation;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Builder(
              builder: (context) => Text(
                localizeSourcePluginText(
                  result,
                  Localizations.localeOf(context).toLanguageTag(),
                  translation: translation,
                ),
              ),
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ListTile(
        title: Text(
          localizeSourcePluginText(
            widget.action.title,
            Localizations.localeOf(context).toLanguageTag(),
            translation: widget.translation,
            fallback: widget.action.id,
          ),
        ),
        subtitle: widget.pluginName == null ? null : Text(widget.pluginName!),
        trailing: const Icon(Icons.chevron_right),
        onTap: _busy ? null : _run,
      ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SelectableText(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
    ],
  );
}
