import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/services/source/plugins/source_plugin_localization.dart';
import 'package:hazuki/widgets/widgets.dart';
import 'source_plugin_action_widgets.dart';

class SourcePluginSettingsPage extends StatelessWidget {
  const SourcePluginSettingsPage({
    super.key,
    required this.id,
    required this.gateway,
  });
  final String id;
  final SourcePluginGateway gateway;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: hazukiFrostedAppBar(
      context: context,
      title: Text(l10n(context).settingsTitle),
    ),
    body: SourcePluginSettingsContent(id: id, gateway: gateway),
  );
}

/// Shared controls; the parent page owns its route, title and scaffold.
class SourcePluginSettingsContent extends StatefulWidget {
  const SourcePluginSettingsContent({
    super.key,
    required this.id,
    required this.gateway,
    this.location = SourcePluginActionLocation.plugin,
  });

  final String id;
  final SourcePluginGateway gateway;
  final SourcePluginActionLocation location;
  @override
  State<SourcePluginSettingsContent> createState() =>
      _SourcePluginSettingsContentState();
}

class _SourcePluginSettingsContentState
    extends State<SourcePluginSettingsContent> {
  Map<String, dynamic> _settings = {};
  Map<String, dynamic> _translation = {};
  List<SourcePluginAction> _actions = [];
  String? _error;
  int _loadRevision = 0;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant SourcePluginSettingsContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id || oldWidget.gateway != widget.gateway) {
      _settings = {};
      _translation = {};
      _actions = [];
      _error = null;
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final revision = ++_loadRevision;
    if (widget.id.isEmpty) return;
    try {
      final meta = await widget.gateway.loadMetadata(widget.id);
      final actions = SourcePluginAction.parseList(
        meta?.presentation['actions'],
      );
      final settings = meta?.settings ?? {};
      for (final spec in settings.values.whereType<Map>()) {
        sourcePluginSettingLocation(spec['location']);
      }
      if (mounted && revision == _loadRevision) {
        setState(() {
          _settings = settings;
          _translation = meta?.translation ?? {};
          _actions = actions;
        });
      }
    } catch (error) {
      if (mounted && revision == _loadRevision) {
        setState(() => _error = error.toString());
      }
    }
  }

  Future<void> _set(String key, dynamic value) async {
    try {
      await widget.gateway.saveSetting(widget.id, key, value);
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      if (_error != null) SelectableText(_error!),
      for (final entry in _settings.entries)
        if (entry.value is Map && _showsSetting(entry.value as Map))
          _control(entry.key, Map<String, dynamic>.from(entry.value as Map)),
      if (widget.location == SourcePluginActionLocation.lines)
        SourcePluginActionList(
          gateway: widget.gateway,
          location: SourcePluginActionLocation.lines,
          pluginId: widget.id,
        )
      else
        for (final action in _actions.where(
          (action) => action.location == widget.location,
        ))
          SourcePluginActionTile(
            key: ValueKey((widget.id, action.id)),
            gateway: widget.gateway,
            pluginId: widget.id,
            action: action,
            translation: _translation,
          ),
    ],
  );
  bool _showsSetting(Map spec) {
    final location = sourcePluginSettingLocation(spec['location']);
    return location == widget.location;
  }

  Widget _control(String key, Map<String, dynamic> spec) {
    if (spec['type'] == 'callback') return const SizedBox.shrink();
    final value = widget.gateway.loadSetting(widget.id, key) ?? spec['default'];
    final title = _text(spec['title'], fallback: key);
    if (spec['type'] == 'switch' || spec['type'] == 'bool') {
      return SwitchListTile(
        title: Text(title),
        value: value == true,
        onChanged: (v) => _set(key, v),
      );
    }
    if (spec['options'] is List) {
      final options = (spec['options'] as List).map((option) {
        final id = option is Map
            ? option['value'].toString()
            : option.toString();
        return HazukiFrostedMenuOption<String>(
          value: id,
          label: option is Map
              ? _text(option['label'] ?? option['text'] ?? id, fallback: id)
              : _text(id),
        );
      }).toList();
      final selected =
          options.any((option) => option.value == value?.toString())
          ? value.toString()
          : null;
      return ListTile(
        title: Text(title),
        trailing: HazukiFrostedDropdown<String>(
          selected: selected,
          options: options,
          tooltip: title,
          onSelected: (v) => unawaited(_set(key, v)),
        ),
      );
    }
    return ListTile(
      title: Text(title),
      subtitle: Text(value?.toString() ?? ''),
      onTap: () async {
        final next = await showDialog<String>(
          context: context,
          builder: (_) => _SourcePluginTextSettingDialog(
            title: spec['title'] ?? key,
            translation: _translation,
            value: value?.toString() ?? '',
          ),
        );
        if (next != null && mounted) await _set(key, next);
      },
    );
  }

  String _text(Object? text, {String fallback = ''}) =>
      localizeSourcePluginText(
        text,
        Localizations.localeOf(context).toLanguageTag(),
        translation: _translation,
        fallback: fallback,
      );
}

class _SourcePluginTextSettingDialog extends StatefulWidget {
  const _SourcePluginTextSettingDialog({
    required this.title,
    required this.value,
    required this.translation,
  });
  final Object title;
  final Map<String, dynamic> translation;
  final String value;

  @override
  State<_SourcePluginTextSettingDialog> createState() =>
      _SourcePluginTextSettingDialogState();
}

class _SourcePluginTextSettingDialogState
    extends State<_SourcePluginTextSettingDialog> {
  late final _controller = TextEditingController(text: widget.value);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      localizeSourcePluginText(
        widget.title,
        Localizations.localeOf(context).toLanguageTag(),
        translation: widget.translation,
      ),
    ),
    content: TextField(controller: _controller),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, _controller.text),
        child: Text(l10n(context).commonConfirm),
      ),
    ],
  );
}
