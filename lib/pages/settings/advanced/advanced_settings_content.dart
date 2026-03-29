import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../settings_group.dart';

class AdvancedSettingsContent extends StatelessWidget {
  const AdvancedSettingsContent({
    super.key,
    required this.loading,
    required this.comicIdSearchEnhance,
    required this.noImageMode,
    required this.softwareLogCaptureEnabled,
    required this.hasCustomEditedSource,
    required this.logsPageBuilder,
    required this.onToggleComicIdSearchEnhance,
    required this.onToggleNoImageMode,
    required this.onToggleSoftwareLogCaptureEnabled,
    required this.onOpenComicSourceEditor,
    required this.onRestoreComicSource,
  });

  final bool loading;
  final bool comicIdSearchEnhance;
  final bool noImageMode;
  final bool softwareLogCaptureEnabled;
  final bool hasCustomEditedSource;
  final WidgetBuilder logsPageBuilder;
  final ValueChanged<bool> onToggleComicIdSearchEnhance;
  final ValueChanged<bool> onToggleNoImageMode;
  final ValueChanged<bool> onToggleSoftwareLogCaptureEnabled;
  final Future<void> Function() onOpenComicSourceEditor;
  final Future<void> Function() onRestoreComicSource;

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
              secondary: const Icon(Icons.tag_outlined),
              title: Text(strings.advancedComicIdSearchTitle),
              subtitle: Text(strings.advancedComicIdSearchSubtitle),
              value: comicIdSearchEnhance,
              onChanged: onToggleComicIdSearchEnhance,
            ),
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
                    axisAlignment: -1,
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
