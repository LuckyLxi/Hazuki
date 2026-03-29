import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';
import '../../services/hazuki_source_service.dart';
import '../../widgets/widgets.dart';

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
  final service = sourceService ?? HazukiSourceService.instance;
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
                          TextField(
                            controller: accountController,
                            enabled: !loading,
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
                                          passwordVisible = !passwordVisible;
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
    child: AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      content: HomeProfileCardContent(
        avatarUrl: avatarUrl,
        username: username,
        firstUseText: firstUseText,
        onLogoutTap: onLogoutTap,
        onRequestSaveAvatar: onRequestSaveAvatar,
      ),
    ),
  );
}
