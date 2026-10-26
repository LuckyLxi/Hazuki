import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/services/source/plugins/source_plugin_localization.dart';
import 'package:hazuki/widgets/hazuki_prompt.dart';
import 'package:hazuki/widgets/source_plugin_interaction.dart';

import '../settings_group.dart';
import 'package:hazuki/services/source/interaction/source_ui_scope.dart';

/// Shows declarations from enabled plugins without initializing their runtimes.
class SourcePluginActionList extends StatelessWidget {
  const SourcePluginActionList({
    super.key,
    required this.gateway,
    required this.location,
    this.pluginId,
    this.title,
  });

  final SourcePluginGateway gateway;
  final SourcePluginActionLocation location;
  final String? pluginId;

  /// 分区标题，仅在存在插件操作时随卡片一起显示
  final String? title;

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
      if (tiles.isEmpty) return const SizedBox.shrink();
      final title = this.title;
      if (title == null) return SettingsGroup(children: tiles);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsSectionHeader(title),
          SettingsGroup(children: withSettingsDividers(context, tiles)),
        ],
      );
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
  Future<void> _run() async {
    final scope = SourceUiScope.current;
    try {
      final result = await widget.gateway.runAction(
        widget.pluginId,
        widget.action.id,
      );
      if (mounted && scope?.available != false && result != null) {
        unawaited(
          showHazukiPrompt(
            context,
            localizeSourcePluginText(
              result,
              Localizations.localeOf(context).toLanguageTag(),
              translation: widget.translation,
            ),
          ),
        );
      }
    } catch (error) {
      if (isSourceUiCancellation(error)) return;
      if (mounted && scope?.available != false) {
        unawaited(showHazukiPrompt(context, error.toString(), isError: true));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = localizeSourcePluginText(
      widget.action.title,
      Localizations.localeOf(context).toLanguageTag(),
      translation: widget.translation,
      fallback: widget.action.id,
    );
    return SourcePluginButtonInteraction.action(
      id: widget.action.id,
      title: title,
      sourceKey: widget.pluginId,
      gateway: widget.gateway,
      onInvoke: _run,
      builder: (context, activate) => ListTile(
        title: Text(title),
        subtitle: widget.pluginName == null ? null : Text(widget.pluginName!),
        trailing: const Icon(Icons.chevron_right),
        onTap: activate,
      ),
    );
  }
}
