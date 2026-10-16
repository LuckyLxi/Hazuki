import 'package:flutter/material.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/software_update/software_update_service.dart';
import 'package:hazuki/widgets/widgets.dart';
import '../settings_group.dart';

class AdvancedSettingsContent extends StatelessWidget {
  const AdvancedSettingsContent({
    super.key,
    required this.loading,
    required this.noImageMode,
    required this.softwareLogCaptureEnabled,
    required this.autoSourceUpdateCheckEnabled,
    required this.autoSoftwareUpdateCheckEnabled,
    required this.softwareUpdateSource,
    required this.hasSourceBackup,
    required this.logsPageBuilder,
    required this.onToggleNoImageMode,
    required this.onToggleSoftwareLogCaptureEnabled,
    required this.onToggleAutoSourceUpdateCheck,
    required this.onToggleAutoSoftwareUpdateCheck,
    required this.onSoftwareUpdateSourceChanged,
    required this.onOpenComicSourceEditor,
    required this.onRestoreComicSource,
    this.onRedownloadComicSource,
    this.sourceDeviceAction,
    this.footer,
  });

  final bool loading;
  final bool noImageMode;
  final bool softwareLogCaptureEnabled;
  final bool autoSourceUpdateCheckEnabled;
  final bool autoSoftwareUpdateCheckEnabled;
  final SoftwareUpdateSource softwareUpdateSource;
  final bool hasSourceBackup;
  final WidgetBuilder logsPageBuilder;
  final ValueChanged<bool> onToggleNoImageMode;
  final ValueChanged<bool> onToggleSoftwareLogCaptureEnabled;
  final ValueChanged<bool> onToggleAutoSourceUpdateCheck;
  final ValueChanged<bool> onToggleAutoSoftwareUpdateCheck;
  final ValueChanged<SoftwareUpdateSource> onSoftwareUpdateSourceChanged;
  final Future<void> Function() onOpenComicSourceEditor;
  final Future<void> Function() onRestoreComicSource;
  final Future<void> Function()? onRedownloadComicSource;
  final Widget? sourceDeviceAction;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        SettingsGroup(
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.image_not_supported_outlined),
              title: Text(strings.advancedNoImageModeTitle),
              subtitle: Text(strings.advancedNoImageModeSubtitle),
              value: noImageMode,
              onChanged: onToggleNoImageMode,
            ),
          ],
        ),
        SettingsGroup(
          children: [
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: Text(strings.advancedDebugTitle),
              subtitle: Text(strings.advancedDebugSubtitle),
              onTap: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute<void>(builder: logsPageBuilder));
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.bug_report_outlined),
              title: Text(strings.advancedSoftwareLogCaptureTitle),
              subtitle: Text(strings.advancedSoftwareLogCaptureSubtitle),
              value: softwareLogCaptureEnabled,
              onChanged: onToggleSoftwareLogCaptureEnabled,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.system_update_alt_rounded),
              title: Text(strings.otherAutoSourceUpdateTitle),
              subtitle: Text(strings.otherAutoSourceUpdateSubtitle),
              value: autoSourceUpdateCheckEnabled,
              onChanged: onToggleAutoSourceUpdateCheck,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.mobile_friendly_rounded),
              title: Text(strings.otherAutoSoftwareUpdateTitle),
              subtitle: Text(strings.otherAutoSoftwareUpdateSubtitle),
              value: autoSoftwareUpdateCheckEnabled,
              onChanged: onToggleAutoSoftwareUpdateCheck,
            ),
            ListTile(
              leading: const Icon(Icons.system_update_alt_outlined),
              title: Text(strings.advancedSoftwareUpdateSourceTitle),
              subtitle: Text(strings.advancedSoftwareUpdateSourceSubtitle),
              trailing: HazukiFrostedDropdown<SoftwareUpdateSource>(
                selected: softwareUpdateSource,
                tooltip: strings.advancedSoftwareUpdateSourceTitle,
                onSelected: onSoftwareUpdateSourceChanged,
                options: const [
                  HazukiFrostedMenuOption(
                    value: SoftwareUpdateSource.jsDelivr,
                    label: 'jsdelivr',
                  ),
                  HazukiFrostedMenuOption(
                    value: SoftwareUpdateSource.github,
                    label: 'GitHub',
                  ),
                  HazukiFrostedMenuOption(
                    value: SoftwareUpdateSource.ghproxy,
                    label: 'ghproxy',
                  ),
                ],
              ),
            ),
            ?sourceDeviceAction,
            ListTile(
              leading: const Icon(Icons.javascript_rounded),
              title: Text(strings.advancedEditSourceTitle),
              subtitle: Text(strings.advancedEditSourceSubtitle),
              onTap: onOpenComicSourceEditor,
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SizeTransition(
                    sizeFactor: animation,
                    alignment: const AlignmentDirectional(-1.0, -1.0),
                    child: child,
                  ),
                );
              },
              child: hasSourceBackup
                  ? Padding(
                      key: const ValueKey<String>('restore-comic-source'),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: FilledButton.tonalIcon(
                        onPressed: onRestoreComicSource,
                        icon: const Icon(Icons.restore_rounded),
                        label: Text(strings.sourceBackupRestoreTitle),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          alignment: Alignment.centerLeft,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(
                      key: ValueKey<String>('restore-comic-source-empty'),
                    ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SizeTransition(
                    sizeFactor: animation,
                    alignment: const AlignmentDirectional(-1.0, -1.0),
                    child: child,
                  ),
                );
              },
              child: hasSourceBackup && onRedownloadComicSource != null
                  ? ListTile(
                      key: const ValueKey('redownload-comic-source'),
                      leading: const Icon(Icons.download_rounded),
                      title: Text(strings.sourceRedownloadTitle),
                      onTap: onRedownloadComicSource,
                    )
                  : const SizedBox.shrink(
                      key: ValueKey('redownload-comic-source-empty'),
                    ),
            ),
          ],
        ),
        ?footer,
      ],
    );
  }
}
