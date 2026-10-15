import 'package:flutter/material.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/widgets/widgets.dart';
import '../settings_group.dart';
import '../plugins/source_plugin_action_widgets.dart';

class LabSettingsPage extends StatelessWidget {
  const LabSettingsPage({super.key, required this.sourcePlugins});

  final SourcePluginGateway sourcePlugins;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: hazukiFrostedAppBar(
        context: context,
        title: Text(strings.labTitle),
      ),
      body: HazukiSettingsPageBody(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            SourcePluginActionList(
              gateway: sourcePlugins,
              location: SourcePluginActionLocation.lab,
            ),
          ],
        ),
      ),
    );
  }
}
