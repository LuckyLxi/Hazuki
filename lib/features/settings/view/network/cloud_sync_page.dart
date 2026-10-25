import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hazuki/shared/cloud_sync/cloud_sync_restore_handler.dart';
import 'package:hazuki/features/settings/state/cloud_sync_controller.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/cloud_sync_service.dart';
import 'package:hazuki/widgets/widgets.dart';
import '../settings_group.dart';

part 'cloud_sync_action_tile.dart';
part 'cloud_sync_server_card.dart';
part 'cloud_sync_server_sheet.dart';

const _cloudSyncMotion = Duration(milliseconds: 280);

/// 成功态配色，深浅色主题下保持足够对比度。
Color _cloudSyncSuccessColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? Colors.green.shade300
      : Colors.green.shade700;
}

/// 切换时新旧内容顶部对齐叠放，配合 AnimatedSize 避免高度跳动。
Widget _cloudSyncTopAlignedLayout(
  Widget? currentChild,
  List<Widget> previousChildren,
) {
  return Stack(
    alignment: Alignment.topCenter,
    children: [...previousChildren, ?currentChild],
  );
}

/// 区块显隐：淡入并自上而下展开。
Widget _cloudSyncRevealTransition(Widget child, Animation<double> animation) {
  final curved = CurvedAnimation(
    parent: animation,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  return FadeTransition(
    opacity: curved,
    child: SizeTransition(
      sizeFactor: curved,
      alignment: Alignment.topCenter,
      child: child,
    ),
  );
}

/// 小部件互换：淡入并从略小尺寸放大。
Widget _cloudSyncPopTransition(Widget child, Animation<double> animation) {
  return FadeTransition(
    opacity: animation,
    child: ScaleTransition(
      scale: Tween<double>(begin: 0.85, end: 1).animate(animation),
      child: child,
    ),
  );
}

class CloudSyncPage extends StatefulWidget {
  const CloudSyncPage({super.key, required this.service});

  final CloudSyncService service;

  @override
  State<CloudSyncPage> createState() => _CloudSyncPageState();
}

class _CloudSyncPageState extends State<CloudSyncPage> {
  late final CloudSyncController _controller;
  CloudSyncAction? _completedAction;
  Timer? _completedTimer;

  @override
  void initState() {
    super.initState();
    _controller = CloudSyncController(service: widget.service);
    unawaited(_controller.loadConfig());
  }

  @override
  void dispose() {
    _completedTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// 动作完成后在对应条目上短暂显示完成标记。
  void _flashCompleted(CloudSyncAction action) {
    _completedTimer?.cancel();
    setState(() => _completedAction = action);
    _completedTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _completedAction = null);
    });
  }

  Future<void> _openServerSheet() {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CloudSyncServerSheet(controller: _controller),
    );
  }

  Future<void> _uploadBackup() async {
    final strings = AppLocalizations.of(context)!;
    try {
      await _controller.uploadBackup();
      if (!mounted) return;
      _flashCompleted(CloudSyncAction.upload);
      unawaited(showHazukiPrompt(context, strings.cloudSyncUploadCompleted));
    } catch (e) {
      if (!mounted) return;
      unawaited(
        showHazukiPrompt(
          context,
          strings.cloudSyncUploadFailed('$e'),
          isError: true,
        ),
      );
    }
  }

  Future<void> _restoreBackup() async {
    final strings = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(strings.cloudSyncRestoreTitle),
          content: Text(strings.cloudSyncRestoreContent),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(strings.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(strings.cloudSyncRestoreConfirm),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    try {
      final outcome = await _controller.restoreBackup(
        applyRestore: (result) =>
            HazukiAppControllerScope.of(context).applyCloudSyncRestore(result),
      );
      if (!mounted) return;
      _flashCompleted(CloudSyncAction.restore);
      final message = StringBuffer(strings.cloudSyncRestoreCompleted);
      if (outcome.skippedPlatformSettings) {
        message.write('\n${strings.cloudSyncRestoreSkippedPlatformSettings}');
      }
      unawaited(showHazukiPrompt(context, message.toString()));
    } catch (e) {
      if (!mounted) return;
      unawaited(
        showHazukiPrompt(
          context,
          strings.cloudSyncRestoreFailed('$e'),
          isError: true,
        ),
      );
    }
  }

  _CloudSyncServerStatus _resolveServerStatus() {
    // 保存配置时也会检测连接，统一视为检测中。
    if (_controller.checkingConnectivity || _controller.saving) {
      return _CloudSyncServerStatus.checking;
    }
    final status = _controller.status;
    if (status == null) return _CloudSyncServerStatus.unchecked;
    return status.ok
        ? _CloudSyncServerStatus.connected
        : _CloudSyncServerStatus.disconnected;
  }

  Widget _buildServerSection() {
    final configured = _controller.isConfigComplete;
    final busy = _controller.saving || _controller.syncing;
    return AnimatedSize(
      duration: _cloudSyncMotion,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: _cloudSyncMotion,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: _cloudSyncTopAlignedLayout,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(animation),
            child: child,
          ),
        ),
        child: configured
            ? _CloudSyncServerCard(
                key: const ValueKey('cloud-sync-server-card'),
                url: _controller.urlController.text.trim(),
                username: _controller.usernameController.text.trim(),
                status: _resolveServerStatus(),
                failureMessage: _controller.status?.message ?? '',
                onTest: busy || _controller.checkingConnectivity
                    ? null
                    : () => unawaited(_controller.testConnection()),
                onEdit: busy ? null : _openServerSheet,
              )
            : _CloudSyncEmptyServerCard(
                key: const ValueKey('cloud-sync-empty-server'),
                onAdd: _openServerSheet,
              ),
      ),
    );
  }

  Widget _buildActionsSection(AppLocalizations strings) {
    final theme = Theme.of(context);
    final configured = _controller.isConfigComplete;
    final actionsEnabled =
        configured && !_controller.saving && !_controller.syncing;
    final activeAction = _controller.activeAction;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
          child: Text(
            strings.cloudSyncActionsTitle,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        AnimatedOpacity(
          opacity: configured ? 1 : 0.45,
          duration: _cloudSyncMotion,
          curve: Curves.easeOutCubic,
          child: SettingsGroup(
            children: [
              _CloudSyncActionTile(
                icon: Icons.cloud_upload_outlined,
                title: strings.cloudSyncUpload,
                subtitle: strings.cloudSyncUploadSubtitle,
                busySubtitle: strings.cloudSyncUploading,
                busy: activeAction == CloudSyncAction.upload,
                completed: _completedAction == CloudSyncAction.upload,
                onTap: actionsEnabled ? _uploadBackup : null,
              ),
              _CloudSyncActionTile(
                icon: Icons.settings_backup_restore_rounded,
                title: strings.cloudSyncRestore,
                subtitle: strings.cloudSyncRestoreSubtitle,
                busySubtitle: strings.cloudSyncRestoring,
                busy: activeAction == CloudSyncAction.restore,
                completed: _completedAction == CloudSyncAction.restore,
                onTap: actionsEnabled ? _restoreBackup : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: hazukiFrostedAppBar(
        context: context,
        title: Text(strings.cloudSyncTitle),
      ),
      body: HazukiSettingsPageBody(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            if (_controller.loading) {
              return const Center(child: CircularProgressIndicator());
            }

            return ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                SettingsGroup(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.cloud_sync_outlined),
                      value: _controller.enabled,
                      title: Text(strings.cloudSyncEnabledTitle),
                      subtitle: Text(strings.cloudSyncEnabledSubtitle),
                      onChanged: (value) => _controller.setEnabled(value),
                    ),
                  ],
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 360),
                  reverseDuration: const Duration(milliseconds: 240),
                  layoutBuilder: _cloudSyncTopAlignedLayout,
                  transitionBuilder: _cloudSyncRevealTransition,
                  child: _controller.enabled
                      ? Column(
                          key: const ValueKey('cloud-sync-enabled'),
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildServerSection(),
                            _buildActionsSection(strings),
                          ],
                        )
                      : const SizedBox(
                          key: ValueKey('cloud-sync-disabled'),
                          width: double.infinity,
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
