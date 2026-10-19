import 'dart:async';
import 'package:hazuki/services/source/account/source_login_interaction.dart';
import 'source_login_interaction_text.dart';
import 'source_login_interaction_dialog.dart';
import 'source_login_dialog_controller.dart';
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
  bool useGlassTransition = false,
}) {
  final clearGlass = useGlassTransition && HazukiLiquidGlass.isAvailable;
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: l10n(context).dialogBarrierLabel,
    barrierColor: clearGlass
        ? Colors.black.withValues(alpha: 0.18)
        : Colors.black45,
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (buildContext, animation, secondaryAnimation) {
      return SafeArea(
        child: Center(
          child: Material(type: MaterialType.transparency, child: child),
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
          final progress = curved.value;
          return Stack(
            fit: StackFit.expand,
            children: [
              // Backdrop filters must read the page directly, without an
              // ancestor opacity layer isolating them during the transition.
              IgnorePointer(
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: (clearGlass ? 1.2 : 8) * progress,
                      sigmaY: (clearGlass ? 1.2 : 8) * progress,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
              ScaleTransition(
                scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
                child: useGlassTransition
                    ? _HomeDialogGlassProgress(
                        progress: progress,
                        child: dialogChild,
                      )
                    : FadeTransition(opacity: curved, child: dialogChild),
              ),
            ],
          );
        },
  );
}

class _HomeDialogGlassProgress extends InheritedWidget {
  const _HomeDialogGlassProgress({
    required this.progress,
    required super.child,
  });

  final double progress;

  static double of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_HomeDialogGlassProgress>()
          ?.progress ??
      1;

  @override
  bool updateShouldNotify(_HomeDialogGlassProgress oldWidget) =>
      progress != oldWidget.progress;
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
  List<SourceLoginMethod> loginMethods = const [],
  SourceLoginDialogController? interactionController,
  Future<HomeLoginDialogProfile> Function(
    String account,
    String password,
    String method,
    SourceLoginPresenter present,
  )?
  onLoginMethod,
  VoidCallback? onDismissed,
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
  final interactions = interactionController ?? SourceLoginDialogController();
  var selectedMethod = loginMethods.firstOrNull;
  var loading = false;
  var showProfileCard = false;
  var passwordVisible = false;
  String? errorText;
  var profileUsername = initialUsername;
  var profileAvatarUrl = initialAvatarUrl;

  final strings = l10n(context);

  await showHomeAnimatedDialog<void>(
    context,
    child: _LoginControllerLifetime(
      controllers: [accountController, passwordController],
      onDisposed: () {
        interactions.cancel();
        onDismissed?.call();
        if (interactionController == null) interactions.dispose();
      },
      child: StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return PopScope(
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) {
                interactions.cancel();
                onDismissed?.call();
              }
            },
            child: Dialog(
              backgroundColor: homeDialogBackgroundColor(dialogContext),
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 360),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: ValueListenableBuilder<Widget?>(
                  valueListenable: interactions,
                  builder: (context, step, _) => AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    layoutBuilder: (currentChild, previousChildren) {
                      // Keep the same keyed wrapper when a step becomes an
                      // outgoing child so its state and completion survive.
                      Widget place(Widget child, {bool outgoing = false}) =>
                          Positioned(
                            key: child.key,
                            top: outgoing ? 0 : null,
                            left: outgoing ? 0 : null,
                            right: outgoing ? 0 : null,
                            child: IgnorePointer(
                              ignoring: outgoing,
                              child: ExcludeFocus(
                                excluding: outgoing,
                                child: ExcludeSemantics(
                                  excluding: outgoing,
                                  child: child,
                                ),
                              ),
                            ),
                          );
                      return Stack(
                        alignment: Alignment.topCenter,
                        children: <Widget>[
                          for (final previous in previousChildren)
                            place(previous, outgoing: true),
                          if (currentChild != null) place(currentChild),
                        ],
                      );
                    },
                    transitionBuilder: (child, animation) =>
                        FadeTransition(opacity: animation, child: child),
                    child:
                        step ??
                        (showProfileCard
                            ? Container(
                                key: const ValueKey('profile-card'),
                                width: 320,
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  8,
                                ),
                                child: SingleChildScrollView(
                                  child: HomeProfileCardContent(
                                    avatarUrl: profileAvatarUrl,
                                    username: profileUsername,
                                    firstUseText: firstUseText,
                                    onLogoutTap: () {
                                      Navigator.pop(dialogContext);
                                      onLogoutTap();
                                    },
                                    onRequestSaveAvatar: () {
                                      return onRequestSaveAvatar(
                                        profileAvatarUrl,
                                      );
                                    },
                                  ),
                                ),
                              )
                            : loading
                            ? SizedBox(
                                key: const ValueKey('login-loading'),
                                width: 320,
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const CircularProgressIndicator(),
                                      const SizedBox(height: 20),
                                      Text(strings.commonLoading),
                                      const SizedBox(height: 16),
                                      TextButton(
                                        onPressed: () {
                                          onDismissed?.call();
                                          Navigator.pop(dialogContext);
                                        },
                                        child: Text(strings.commonCancel),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : SingleChildScrollView(
                                child: Container(
                                  key: const ValueKey('login-form'),
                                  width: 320,
                                  padding: const EdgeInsets.fromLTRB(
                                    24,
                                    24,
                                    24,
                                    16,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        strings.homeLoginTitle,
                                        style: Theme.of(
                                          dialogContext,
                                        ).textTheme.headlineSmall,
                                      ),
                                      const SizedBox(height: 20),
                                      if (loginMethods.isNotEmpty)
                                        IgnorePointer(
                                          ignoring: loading,
                                          child: HazukiFrostedDropdown<String>(
                                            selected: selectedMethod!.id,
                                            options: [
                                              for (final method in loginMethods)
                                                HazukiFrostedMenuOption(
                                                  value: method.id,
                                                  label: loginInteractionText(
                                                    dialogContext,
                                                    method.title,
                                                  ),
                                                ),
                                            ],
                                            onSelected: (id) =>
                                                setDialogState(() {
                                                  selectedMethod = loginMethods
                                                      .firstWhere(
                                                        (m) => m.id == id,
                                                      );
                                                  errorText = null;
                                                }),
                                          ),
                                        ),
                                      AutofillGroup(
                                        child: Column(
                                          children: [
                                            if (selectedMethod?.input != 'none')
                                              TextField(
                                                controller: accountController,
                                                enabled: !loading,
                                                autofillHints: const [
                                                  AutofillHints.username,
                                                  AutofillHints.email,
                                                ],
                                                textInputAction:
                                                    TextInputAction.next,
                                                keyboardType:
                                                    TextInputType.emailAddress,
                                                decoration: InputDecoration(
                                                  labelText: strings
                                                      .homeLoginAccountLabel,
                                                  border:
                                                      const OutlineInputBorder(),
                                                ),
                                              ),
                                            if (selectedMethod == null ||
                                                selectedMethod?.input ==
                                                    'credentials') ...[
                                              const SizedBox(height: 16),
                                              TextField(
                                                controller: passwordController,
                                                enabled: !loading,
                                                obscureText: !passwordVisible,
                                                autofillHints: const [
                                                  AutofillHints.password,
                                                ],
                                                textInputAction:
                                                    TextInputAction.done,
                                                decoration: InputDecoration(
                                                  labelText: strings
                                                      .homeLoginPasswordLabel,
                                                  border:
                                                      const OutlineInputBorder(),
                                                  suffixIcon: IconButton(
                                                    tooltip: passwordVisible
                                                        ? strings
                                                              .homeLoginHidePassword
                                                        : strings
                                                              .homeLoginShowPassword,
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
                                                          ? Icons
                                                                .visibility_off_outlined
                                                          : Icons
                                                                .visibility_outlined,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
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
                                      OverflowBar(
                                        alignment: MainAxisAlignment.end,
                                        spacing: 8,
                                        children: [
                                          TextButton(
                                            onPressed:
                                                loading &&
                                                    selectedMethod == null
                                                ? null
                                                : () {
                                                    onDismissed?.call();
                                                    Navigator.pop(
                                                      dialogContext,
                                                    );
                                                  },
                                            child: Text(strings.commonCancel),
                                          ),
                                          FilledButton(
                                            onPressed: loading
                                                ? null
                                                : () async {
                                                    final account =
                                                        accountController.text
                                                            .trim();
                                                    final password =
                                                        passwordController.text;
                                                    final input =
                                                        selectedMethod?.input ??
                                                        'credentials';
                                                    if (input != 'none' &&
                                                            account.isEmpty ||
                                                        input ==
                                                                'credentials' &&
                                                            password.isEmpty) {
                                                      setDialogState(() {
                                                        errorText = strings
                                                            .homeLoginEmptyError;
                                                      });
                                                      return;
                                                    }

                                                    setDialogState(() {
                                                      loading = true;
                                                      errorText = null;
                                                    });

                                                    try {
                                                      final profile =
                                                          selectedMethod == null
                                                          ? await onLogin(
                                                              account,
                                                              password,
                                                            )
                                                          : await onLoginMethod!(
                                                              selectedMethod!
                                                                          .input ==
                                                                      'none'
                                                                  ? ''
                                                                  : account,
                                                              selectedMethod!
                                                                          .input ==
                                                                      'credentials'
                                                                  ? password
                                                                  : '',
                                                              selectedMethod!
                                                                  .id,
                                                              (
                                                                request,
                                                                cancellation,
                                                              ) => showSourceLoginInteraction(
                                                                dialogContext,
                                                                request,
                                                                cancellation,
                                                                dialogController:
                                                                    interactions,
                                                              ),
                                                            );
                                                      if (!dialogContext
                                                              .mounted ||
                                                          ModalRoute.of(
                                                                dialogContext,
                                                              )?.isCurrent !=
                                                              true) {
                                                        return;
                                                      }
                                                      setDialogState(() {
                                                        loading = false;
                                                        showProfileCard = true;
                                                        profileUsername =
                                                            profile.username;
                                                        profileAvatarUrl =
                                                            profile.avatarUrl;
                                                      });
                                                    } catch (error) {
                                                      if (!dialogContext
                                                          .mounted) {
                                                        return;
                                                      }
                                                      final route =
                                                          ModalRoute.of(
                                                            dialogContext,
                                                          );
                                                      if (error
                                                          is SourceLoginCancelled) {
                                                        if (route?.isActive ==
                                                            true) {
                                                          if (route!
                                                              .isCurrent) {
                                                            Navigator.pop(
                                                              dialogContext,
                                                            );
                                                          } else {
                                                            Navigator.of(
                                                              dialogContext,
                                                            ).removeRoute(
                                                              route,
                                                            );
                                                          }
                                                        }
                                                        return;
                                                      }
                                                      if (route?.isCurrent !=
                                                          true) {
                                                        return;
                                                      }
                                                      setDialogState(() {
                                                        loading = false;
                                                        errorText = error
                                                            .toString();
                                                      });
                                                    }
                                                  },
                                            child: loading
                                                ? const SizedBox(
                                                    width: 18,
                                                    height: 18,
                                                    child:
                                                        CircularProgressIndicator(
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
                              )),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );

  onDismissed?.call();
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
    useGlassTransition: true,
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
    return ListenableBuilder(
      listenable: HazukiLiquidGlass.changes,
      builder: (context, _) => _buildCard(context),
    );
  }

  Widget _buildCard(BuildContext context) {
    final progress = _HomeDialogGlassProgress.of(context);
    final content = HomeProfileCardContent(
      avatarUrl: avatarUrl,
      username: username,
      firstUseText: firstUseText,
      onLogoutTap: onLogoutTap,
      onRequestSaveAvatar: onRequestSaveAvatar,
    );

    if (HazukiLiquidGlass.isAvailable) {
      return ClipRSuperellipse(
        borderRadius: BorderRadius.circular(_borderRadius),
        clipBehavior: Clip.antiAlias,
        child: GlassContainer(
          key: const ValueKey('home-profile-liquid-glass-card'),
          width: _width,
          padding: _padding,
          useOwnLayer: true,
          quality: HazukiLiquidGlass.navigationQuality,
          shape: const LiquidRoundedSuperellipse(borderRadius: _borderRadius),
          settings: HazukiLiquidGlass.popoverSettings(
            context,
            visibility: progress,
          ),
          clipBehavior: Clip.antiAlias,
          child: content,
        ),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    return ClipRRect(
      key: const ValueKey('home-profile-frosted-glass-card'),
      borderRadius: BorderRadius.circular(_borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24 * progress, sigmaY: 24 * progress),
        child: Container(
          width: _width,
          padding: _padding,
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.72 * progress),
            borderRadius: BorderRadius.circular(_borderRadius),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(
                alpha: 0.4 * progress,
              ),
            ),
          ),
          child: Opacity(opacity: progress, child: content),
        ),
      ),
    );
  }
}

class _LoginControllerLifetime extends StatefulWidget {
  const _LoginControllerLifetime({
    required this.controllers,
    required this.child,
    this.onDisposed,
  });
  final List<TextEditingController> controllers;
  final VoidCallback? onDisposed;
  final Widget child;
  @override
  State<_LoginControllerLifetime> createState() =>
      _LoginControllerLifetimeState();
}

class _LoginControllerLifetimeState extends State<_LoginControllerLifetime> {
  @override
  Widget build(BuildContext context) => widget.child;
  @override
  void dispose() {
    widget.onDisposed?.call();
    for (final controller in widget.controllers) {
      controller.dispose();
    }
    super.dispose();
  }
}
