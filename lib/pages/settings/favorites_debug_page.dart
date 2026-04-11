import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../widgets/widgets.dart';
import 'logs/logs_export_button.dart';
import 'logs/logs_tabs.dart';
import 'settings_group.dart';

class LogsPage extends StatelessWidget {
  const LogsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: hazukiFrostedAppBar(
          context: context,
          title: Text(strings.advancedDebugTitle),
          actions: const [LogsAppBarExportButton()],
          bottom: TabBar(
            tabs: [
              Tab(
                icon: const Icon(Icons.wifi_tethering_rounded),
                text: strings.logsNetworkTitle,
              ),
              Tab(
                icon: const Icon(Icons.description_outlined),
                text: strings.logsApplicationTitle,
              ),
              Tab(
                icon: const Icon(Icons.chrome_reader_mode_outlined),
                text: strings.logsReaderTitle,
              ),
            ],
          ),
        ),
        body: const HazukiSettingsPageBody(
          child: TabBarView(
            children: [NetworkLogsTab(), ApplicationLogsTab(), ReaderLogsTab()],
          ),
        ),
      ),
    );
  }
}

@Deprecated('Use LogsPage')
class FavoritesDebugPage extends LogsPage {
  const FavoritesDebugPage({super.key});
}
