import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/shared/liquid_glass_support.dart';
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

Color homeDialogBackgroundColor(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  final brightness = ThemeData.estimateBrightnessForColor(colorScheme.surface);
  return brightness == Brightness.dark
      ? colorScheme.surfaceContainerLow
      : colorScheme.surfaceContainerHigh;
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
        Material(
          color: Colors.transparent,
          child: ListTile(
            leading: const Icon(Icons.logout),
            title: Text(l10n(context).homeLogoutTitle),
            onTap: onLogoutTap,
          ),
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
          backgroundColor: homeDialogBackgroundColor(dialogContext),
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
                          AutofillGroup(
                            child: Column(
                              children: [
                                TextField(
                                  controller: accountController,
                                  enabled: !loading,
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
    child: _HomeProfileGlassCard(
      avatarUrl: avatarUrl,
      username: username,
      firstUseText: firstUseText,
      onLogoutTap: onLogoutTap,
      onRequestSaveAvatar: onRequestSaveAvatar,
    ),
  );
}

class _HomeProfileGlassCard extends StatelessWidget {
  const _HomeProfileGlassCard({
    required this.avatarUrl,
    required this.username,
    required this.firstUseText,
    required this.onLogoutTap,
    required this.onRequestSaveAvatar,
  });

  static const _borderRadius = 28.0;
  static const _width = 252.0;
  static const _padding = EdgeInsets.fromLTRB(16, 16, 16, 8);

  final String avatarUrl;
  final String username;
  final String firstUseText;
  final VoidCallback onLogoutTap;
  final Future<void> Function() onRequestSaveAvatar;

  @override
  Widget build(BuildContext context) {
    final content = HomeProfileCardContent(
      avatarUrl: avatarUrl,
      username: username,
      firstUseText: firstUseText,
      onLogoutTap: onLogoutTap,
      onRequestSaveAvatar: onRequestSaveAvatar,
    );

    if (HazukiLiquidGlass.isAvailable) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return GlassContainer(
        key: const ValueKey('home-profile-liquid-glass-card'),
        width: _width,
        padding: _padding,
        useOwnLayer: true,
        quality: HazukiLiquidGlass.navigationQuality,
        shape: const LiquidRoundedSuperellipse(borderRadius: _borderRadius),
        settings: LiquidGlassSettings(
          thickness: 34,
          blur: 4,
          chromaticAberration: 0.16,
          lightIntensity: 0.72,
          refractiveIndex: 1.56,
          saturation: 1.06,
          ambientStrength: 0.3,
          glowIntensity: 0.5,
          shadowElevation: 0,
          glassColor: Colors.white.withValues(alpha: isDark ? 0.1 : 0.18),
          backerColor: isDark
              ? Colors.black.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.06),
        ),
        clipBehavior: Clip.antiAlias,
        child: content,
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    return ClipRRect(
      key: const ValueKey('home-profile-frosted-glass-card'),
      borderRadius: BorderRadius.circular(_borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          width: _width,
          padding: _padding,
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(_borderRadius),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: content,
        ),
      ),
    );
  }
}
