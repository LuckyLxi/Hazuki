import 'package:flutter/material.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/widgets/widgets.dart';
import '../plugins/source_plugin_settings_page.dart';

class LineSettingsPage extends StatelessWidget {
  const LineSettingsPage({
    super.key,
    required this.sourceService,
    required this.sourcePlugins,
  });
  final SourceSettingsGateway sourceService;
  final SourcePluginGateway sourcePlugins;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: hazukiFrostedAppBar(
      context: context,
      title: Text(l10n(context).lineSettingsTitle),
    ),
    body: SourcePluginSettingsContent(
      id: (sourceService.activeSourceKey ?? ''),
      gateway: sourcePlugins,
      location: SourcePluginActionLocation.lines,
    ),
  );
}
