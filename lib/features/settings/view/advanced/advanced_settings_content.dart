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

    Widget section(String title, List<Widget> children) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSectionHeader(title),
        SettingsGroup(children: children),
      ],
    );

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        section(strings.otherSectionDisplay, [
          SwitchListTile(
            secondary: const SettingsLeadingIcon(
              Icons.image_not_supported_outlined,
            ),
            title: Text(strings.advancedNoImageModeTitle),
            subtitle: Text(strings.advancedNoImageModeSubtitle),
            value: noImageMode,
            onChanged: onToggleNoImageMode,
          ),
        ]),
        section(
          strings.advancedSectionUpdate,
          withSettingsDividers(context, [
            SwitchListTile(
              secondary: const SettingsLeadingIcon(
                Icons.system_update_alt_rounded,
              ),
              title: Text(strings.otherAutoSourceUpdateTitle),
              subtitle: Text(strings.otherAutoSourceUpdateSubtitle),
              value: autoSourceUpdateCheckEnabled,
              onChanged: onToggleAutoSourceUpdateCheck,
            ),
            SwitchListTile(
              secondary: const SettingsLeadingIcon(
                Icons.mobile_friendly_rounded,
              ),
              title: Text(strings.otherAutoSoftwareUpdateTitle),
              subtitle: Text(strings.otherAutoSoftwareUpdateSubtitle),
              value: autoSoftwareUpdateCheckEnabled,
              onChanged: onToggleAutoSoftwareUpdateCheck,
            ),
            ListTile(
              leading: const SettingsLeadingIcon(Icons.alt_route_rounded),
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
          ]),
        ),
        section(
          strings.advancedSectionDebug,
          withSettingsDividers(context, [
            SwitchListTile(
              secondary: const SettingsLeadingIcon(Icons.bug_report_outlined),
              title: Text(strings.advancedSoftwareLogCaptureTitle),
              subtitle: Text(strings.advancedSoftwareLogCaptureSubtitle),
              value: softwareLogCaptureEnabled,
              onChanged: onToggleSoftwareLogCaptureEnabled,
            ),
            ListTile(
              leading: const SettingsLeadingIcon(Icons.receipt_long_outlined),
              title: Text(strings.advancedDebugTitle),
              subtitle: Text(strings.advancedDebugSubtitle),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute<void>(builder: logsPageBuilder));
              },
            ),
          ]),
        ),
        section(strings.advancedSectionSource, [
          ...withSettingsDividers(context, [
            ListTile(
              leading: const SettingsLeadingIcon(Icons.javascript_rounded),
              title: Text(strings.advancedEditSourceTitle),
              subtitle: Text(strings.advancedEditSourceSubtitle),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: onOpenComicSourceEditor,
            ),
            ?sourceDeviceAction,
          ]),
          // 备份相关条目按需展开，分隔线随条目一起出现
          _AdvancedRevealSlot(
            child: hasSourceBackup
                ? _AdvancedRevealTile(
                    key: const ValueKey<String>('restore-comic-source'),
                    child: ListTile(
                      leading: const SettingsLeadingIcon(Icons.restore_rounded),
                      title: Text(strings.sourceBackupRestoreTitle),
                      onTap: onRestoreComicSource,
                    ),
                  )
                : const SizedBox.shrink(
                    key: ValueKey<String>('restore-comic-source-empty'),
                  ),
          ),
          _AdvancedRevealSlot(
            child: hasSourceBackup && onRedownloadComicSource != null
                ? _AdvancedRevealTile(
                    key: const ValueKey('redownload-comic-source'),
                    child: ListTile(
                      leading: const SettingsLeadingIcon(
                        Icons.download_rounded,
                      ),
                      title: Text(strings.sourceRedownloadTitle),
                      onTap: onRedownloadComicSource,
                    ),
                  )
                : const SizedBox.shrink(
                    key: ValueKey('redownload-comic-source-empty'),
                  ),
          ),
        ]),
        ?footer,
      ],
    );
  }
}

/// 条目显隐过渡：先撑开高度，内容稍后淡入并轻微下滑；收起时先淡出再收高度。
/// 首次构建不播放动画，进入页面时直接呈现。
class _AdvancedRevealSlot extends StatelessWidget {
  const _AdvancedRevealSlot({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 240),
      // 交给 transitionBuilder 内部分段控制曲线
      switchInCurve: Curves.linear,
      switchOutCurve: Curves.linear,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: AlignmentDirectional.topStart,
        children: [...previousChildren, ?currentChild],
      ),
      transitionBuilder: (child, animation) {
        final size = CurvedAnimation(
          parent: animation,
          curve: const Interval(0, 0.75, curve: Curves.easeOutCubic),
          reverseCurve: const Interval(0, 0.75, curve: Curves.easeInOutCubic),
        );
        final fade = CurvedAnimation(
          parent: animation,
          curve: const Interval(0.3, 1, curve: Curves.easeOut),
          reverseCurve: const Interval(0.4, 1, curve: Curves.easeOut),
        );
        return SizeTransition(
          sizeFactor: size,
          alignment: const AlignmentDirectional(-1.0, -1.0),
          child: FadeTransition(
            opacity: fade,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -0.12),
                end: Offset.zero,
              ).animate(fade),
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

/// 可展开条目：自带顶部分隔线，与分组内其他条目对齐。
class _AdvancedRevealTile extends StatelessWidget {
  const _AdvancedRevealTile({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [settingsDivider(context), child],
    );
  }
}
