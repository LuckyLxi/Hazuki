import 'package:flutter/material.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import '../settings_group.dart';

class AdvancedSettingsContent extends StatelessWidget {
  const AdvancedSettingsContent({
    super.key,
    required this.loading,
    required this.noImageMode,
    required this.softwareLogCaptureEnabled,
    required this.hasCustomEditedSource,
    required this.showCopyMangaSettings,
    required this.logsPageBuilder,
    required this.onToggleNoImageMode,
    required this.onToggleSoftwareLogCaptureEnabled,
    required this.onOpenComicSourceEditor,
    required this.onRestoreComicSource,
    required this.onClearCopyMangaDeviceInfo,
  });

  final bool loading;
  final bool noImageMode;
  final bool softwareLogCaptureEnabled;
  final bool hasCustomEditedSource;
  final bool showCopyMangaSettings;
  final WidgetBuilder logsPageBuilder;
  final ValueChanged<bool> onToggleNoImageMode;
  final ValueChanged<bool> onToggleSoftwareLogCaptureEnabled;
  final Future<void> Function() onOpenComicSourceEditor;
  final Future<void> Function() onRestoreComicSource;
  final Future<void> Function() onClearCopyMangaDeviceInfo;

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
            if (showCopyMangaSettings)
              ListTile(
                leading: const Icon(Icons.phonelink_erase_outlined),
                title: Text(strings.advancedCopyMangaClearDeviceTitle),
                subtitle: Text(strings.advancedCopyMangaClearDeviceSubtitle),
                onTap: onClearCopyMangaDeviceInfo,
              ),
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
              child: hasCustomEditedSource
                  ? Padding(
                      key: const ValueKey<String>('restore-comic-source'),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: FilledButton.tonalIcon(
                        onPressed: onRestoreComicSource,
                        icon: const Icon(Icons.restore_rounded),
                        label: Text(strings.advancedRestoreSourceLabel),
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
          ],
        ),
      ],
    );
  }
}
