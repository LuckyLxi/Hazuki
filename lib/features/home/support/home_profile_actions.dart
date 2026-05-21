import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/app/service_locator.dart';
import 'package:hazuki/services/hazuki_source_service.dart';
import 'package:hazuki/widgets/widgets.dart';

Future<T?> showHomeAnimatedDialog<T>(
  BuildContext context, {
  required Widget child,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: l10n(context).dialogBarrierLabel,
    barrierColor: Colors.black45,
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (buildContext, animation, secondaryAnimation) {
      return SafeArea(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Center(
            child: Material(type: MaterialType.transparency, child: child),
          ),
        ),
      );
    },
    transitionBuilder:
        (buildContext, animation, secondaryAnimation, dialogChild) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
              child: dialogChild,
            ),
          );
        },
  );
}

Future<bool> showHomeLogoutConfirmDialog(BuildContext context) async {
  final strings = l10n(context);
  final result = await showHomeAnimatedDialog<bool>(
    context,
    child: AlertDialog(
      title: Text(strings.homeLogoutTitle),
      content: Text(strings.homeLogoutContent),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(strings.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(strings.homeLogoutTitle),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<bool> showHomeSaveAvatarConfirmDialog(BuildContext context) async {
  final strings = l10n(context);
  final result = await showHomeAnimatedDialog<bool>(
    context,
    child: AlertDialog(
      title: Text(strings.homeSaveAvatarTitle),
      content: Text(strings.homeSaveAvatarContent),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(strings.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(strings.commonSave),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<void> showHomeSourceSwitchDialog(
  BuildContext context, {
  Future<void> Function()? onSourceSwitched,
}) async {
  final registry = sl<SourceRuntimeRegistry>();
  final sourceService = sl<HazukiSourceService>();
  final strings = l10n(context);
  await registry.loadActiveSourcePreference();
  if (!context.mounted) {
    return;
  }

  var switching = false;
  SourceCatalogEntry? switchingSource;
  _HomeSourceSwitchBusyPhase busyPhase = _HomeSourceSwitchBusyPhase.switching;
  String? errorText;

  await showHomeAnimatedDialog<void>(
    context,
    barrierDismissible: true,
    child: StatefulBuilder(
      builder: (dialogContext, setDialogState) {
        Future<void> switchTo(SourceCatalogEntry source) async {
          if (switching || source.normalizedKey == registry.activeSourceKey) {
            return;
          }
          final previousSourceKey = registry.activeSourceKey;
          setDialogState(() {
            switching = true;
            switchingSource = source;
            busyPhase = _HomeSourceSwitchBusyPhase.switching;
            errorText = null;
          });

          try {
            final wasDownloaded = await sourceService.hasLocalSourceFile(
              source.normalizedKey,
            );
            if (!dialogContext.mounted) {
              return;
            }
            setDialogState(() {
              busyPhase = wasDownloaded
                  ? _HomeSourceSwitchBusyPhase.switching
                  : _HomeSourceSwitchBusyPhase.downloading;
            });

            if (!wasDownloaded) {
              await sourceService.downloadSourceFile(source.normalizedKey);
              if (!dialogContext.mounted) {
                return;
              }
              setDialogState(() {
                busyPhase = _HomeSourceSwitchBusyPhase.switching;
              });
            } else {
              await registry.activateSource(source.normalizedKey);
            }
            await sourceService.ensureInitialized(
              sourceKey: source.normalizedKey,
            );
            await onSourceSwitched?.call();
            if (!dialogContext.mounted) {
              return;
            }
            Navigator.of(dialogContext).pop();
            if (!context.mounted) {
              return;
            }
            await showHazukiPrompt(
              context,
              strings.labSourceAccountSwitchSuccess,
            );
          } catch (error) {
            try {
              await registry.activateSource(previousSourceKey);
            } catch (_) {}
            if (!dialogContext.mounted) {
              return;
            }
            setDialogState(() {
              switching = false;
              switchingSource = null;
              busyPhase = _HomeSourceSwitchBusyPhase.switching;
              errorText = strings.labSourceAccountSwitchFailed('$error');
            });
          }
        }

        return PopScope(
          canPop: !switching,
          child: Dialog(
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(switching ? 18 : 28),
            ),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              alignment: Alignment.center,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (currentChild, previousChildren) {
                  return Stack(
                    alignment: Alignment.center,
                    children: <Widget>[...previousChildren, ?currentChild],
                  );
                },
                transitionBuilder: (child, animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: switching
                    ? _HomeSourceSwitchBusyPane(
                        key: const ValueKey('source-switch-busy'),
                        sourceName: switchingSource?.name ?? '',
                        phase: busyPhase,
                      )
                    : _HomeSourceSwitchPickerPane(
                        key: const ValueKey('source-switch-picker'),
                        sources: registry.allowedSources,
                        activeSourceKey: registry.activeSourceKey,
                        errorText: errorText,
                        onCancel: () => Navigator.of(dialogContext).pop(),
                        onSelected: switchTo,
                      ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

Future<void> saveHomeAvatarToDownloads(
  BuildContext context, {
  required MethodChannel mediaChannel,
  required String imageUrl,
  HazukiSourceService? sourceService,
}) async {
  final normalized = imageUrl.trim();
  if (normalized.isEmpty) {
    return;
  }

  final strings = l10n(context);
  final service = sourceService ?? sl<HazukiSourceService>();
  try {
    final bytes = await service.downloadImageBytes(normalized);
    final directory = Directory('/storage/emulated/0/Pictures/Hazuki');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final file = File(
      '${directory.path}/hazuki_avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(bytes, flush: true);
    await mediaChannel.invokeMethod<bool>('scanFile', {'path': file.path});
    if (!context.mounted) {
      return;
    }
    await showHazukiPrompt(context, strings.homeAvatarSaved);
  } catch (error) {
    if (!context.mounted) {
      return;
    }
    await showHazukiPrompt(
      context,
      strings.homeAvatarSaveFailed('$error'),
      isError: true,
    );
  }
}

enum _HomeSourceSwitchBusyPhase { downloading, switching }

class _HomeSourceSwitchPickerPane extends StatelessWidget {
  const _HomeSourceSwitchPickerPane({
    super.key,
    required this.sources,
    required this.activeSourceKey,
    required this.errorText,
    required this.onCancel,
    required this.onSelected,
  });

  final List<SourceCatalogEntry> sources;
  final String activeSourceKey;
  final String? errorText;
  final VoidCallback onCancel;
  final ValueChanged<SourceCatalogEntry> onSelected;

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 340,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              strings.homeSourceSwitchTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            for (final source in sources)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Material(
                  color: source.normalizedKey == activeSourceKey
                      ? colorScheme.primaryContainer.withValues(alpha: 0.58)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    onTap: source.normalizedKey == activeSourceKey
                        ? null
                        : () => onSelected(source),
                    leading: Icon(
                      source.normalizedKey == activeSourceKey
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                    ),
                    title: Text(source.name),
                    subtitle: Text(
                      source.normalizedKey == activeSourceKey
                          ? strings.homeSourceSwitchCurrent
                          : source.key,
                    ),
                  ),
                ),
              ),
            if (errorText != null) ...[
              const SizedBox(height: 8),
              Text(errorText!, style: TextStyle(color: colorScheme.error)),
            ],
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onCancel,
                child: Text(strings.commonCancel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeSourceSwitchBusyPane extends StatelessWidget {
  const _HomeSourceSwitchBusyPane({
    super.key,
    required this.sourceName,
    required this.phase,
  });

  final String sourceName;
  final _HomeSourceSwitchBusyPhase phase;

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final title = switch (phase) {
      _HomeSourceSwitchBusyPhase.downloading =>
        sourceName.trim().isEmpty
            ? strings.sourceBootstrapDownloading
            : strings.homeSourceSwitchDownloadingSource(sourceName),
      _HomeSourceSwitchBusyPhase.switching =>
        sourceName.trim().isEmpty
            ? strings.homeSourceSwitchLoadingTitle
            : strings.homeSourceSwitchLoadingTo(sourceName),
    };

    return SizedBox(
      width: 300,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    strings.homeSourceSwitchLoadingMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeProfileCardContent extends StatelessWidget {
  const HomeProfileCardContent({
    super.key,
    required this.avatarUrl,
    required this.username,
    required this.firstUseText,
    required this.onLogoutTap,
    required this.onRequestSaveAvatar,
  });

  final String avatarUrl;
  final String username;
  final String firstUseText;
  final VoidCallback onLogoutTap;
  final Future<void> Function() onRequestSaveAvatar;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onLongPress: () async {
            unawaited(HapticFeedback.mediumImpact());
            await onRequestSaveAvatar();
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: HazukiCachedImage(
              url: avatarUrl,
              width: 220,
              height: 220,
              fit: BoxFit.cover,
              error: Container(
                width: 220,
                height: 220,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                alignment: Alignment.center,
                child: const Icon(Icons.person, size: 72),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(username, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(firstUseText, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.logout),
          title: Text(l10n(context).homeLogoutTitle),
          onTap: onLogoutTap,
        ),
      ],
    );
  }
}

class HomeLoginDialogProfile {
  const HomeLoginDialogProfile({
    required this.username,
    required this.avatarUrl,
  });

  final String username;
  final String avatarUrl;
}

Future<void> showHomeLoginDialog(
  BuildContext context, {
  required String initialUsername,
  required String initialAvatarUrl,
  required String firstUseText,
  required Future<HomeLoginDialogProfile> Function(
    String account,
    String password,
  )
  onLogin,
  required VoidCallback onLogoutTap,
  required Future<void> Function(String avatarUrl) onRequestSaveAvatar,
}) async {
  final accountController = TextEditingController();
  final passwordController = TextEditingController();
  var loading = false;
  var showProfileCard = false;
  var passwordVisible = false;
  String? errorText;
  var profileUsername = initialUsername;
  var profileAvatarUrl = initialAvatarUrl;

  final strings = l10n(context);

  await showHomeAnimatedDialog<void>(
    context,
    child: StatefulBuilder(
      builder: (dialogContext, setDialogState) {
        return Dialog(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 360),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              layoutBuilder: (currentChild, previousChildren) {
                return Stack(
                  alignment: Alignment.topCenter,
                  children: <Widget>[...previousChildren, ?currentChild],
                );
              },
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: showProfileCard
                  ? Container(
                      key: const ValueKey('profile-card'),
                      width: 320,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          HomeProfileCardContent(
                            avatarUrl: profileAvatarUrl,
                            username: profileUsername,
                            firstUseText: firstUseText,
                            onLogoutTap: () {
                              Navigator.pop(dialogContext);
                              onLogoutTap();
                            },
                            onRequestSaveAvatar: () {
                              return onRequestSaveAvatar(profileAvatarUrl);
                            },
                          ),
                        ],
                      ),
                    )
                  : Container(
                      key: const ValueKey('login-form'),
                      width: 320,
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            strings.homeLoginTitle,
                            style: Theme.of(
                              dialogContext,
                            ).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 20),
                          // 用 AutofillGroup 包裹账号和密码字段，使系统密码填充服务能够识别并自动填充
                          AutofillGroup(
                            child: Column(
                              children: [
                                TextField(
                                  controller: accountController,
                                  enabled: !loading,
                                  // 提示系统这是用户名/邮箱字段
                                  autofillHints: const [
                                    AutofillHints.username,
                                    AutofillHints.email,
                                  ],
                                  textInputAction: TextInputAction.next,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: InputDecoration(
                                    labelText: strings.homeLoginAccountLabel,
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: passwordController,
                                  enabled: !loading,
                                  obscureText: !passwordVisible,
                                  // 提示系统这是密码字段
                                  autofillHints: const [AutofillHints.password],
                                  textInputAction: TextInputAction.done,
                                  decoration: InputDecoration(
                                    labelText: strings.homeLoginPasswordLabel,
                                    border: const OutlineInputBorder(),
                                    suffixIcon: IconButton(
                                      tooltip: passwordVisible
                                          ? strings.homeLoginHidePassword
                                          : strings.homeLoginShowPassword,
                                      onPressed: loading
                                          ? null
                                          : () {
                                              setDialogState(() {
                                                passwordVisible =
                                                    !passwordVisible;
                                              });
                                            },
                                      icon: Icon(
                                        passwordVisible
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (errorText != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              errorText!,
                              style: TextStyle(
                                color: Theme.of(
                                  dialogContext,
                                ).colorScheme.error,
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: loading
                                    ? null
                                    : () => Navigator.pop(dialogContext),
                                child: Text(strings.commonCancel),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                onPressed: loading
                                    ? null
                                    : () async {
                                        final account = accountController.text
                                            .trim();
                                        final password =
                                            passwordController.text;
                                        if (account.isEmpty ||
                                            password.isEmpty) {
                                          setDialogState(() {
                                            errorText =
                                                strings.homeLoginEmptyError;
                                          });
                                          return;
                                        }

                                        setDialogState(() {
                                          loading = true;
                                          errorText = null;
                                        });

                                        try {
                                          final profile = await onLogin(
                                            account,
                                            password,
                                          );
                                          if (!dialogContext.mounted) {
                                            return;
                                          }
                                          setDialogState(() {
                                            loading = false;
                                            showProfileCard = true;
                                            profileUsername = profile.username;
                                            profileAvatarUrl =
                                                profile.avatarUrl;
                                          });
                                        } catch (error) {
                                          if (!dialogContext.mounted) {
                                            return;
                                          }
                                          setDialogState(() {
                                            loading = false;
                                            errorText = error.toString();
                                          });
                                        }
                                      },
                                child: loading
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(strings.homeLoginTitle),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        );
      },
    ),
  );

  accountController.dispose();
  passwordController.dispose();
}

Future<void> showHomeAvatarCard(
  BuildContext context, {
  required String avatarUrl,
  required String username,
  required String firstUseText,
  required VoidCallback onLogoutTap,
  required Future<void> Function() onRequestSaveAvatar,
}) {
  return showHomeAnimatedDialog<void>(
    context,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: IntrinsicWidth(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surface.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: HomeProfileCardContent(
              avatarUrl: avatarUrl,
              username: username,
              firstUseText: firstUseText,
              onLogoutTap: onLogoutTap,
              onRequestSaveAvatar: onRequestSaveAvatar,
            ),
          ),
        ),
      ),
    ),
  );
}
