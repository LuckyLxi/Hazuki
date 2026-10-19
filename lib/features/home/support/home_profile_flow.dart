import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/widgets/widgets.dart';
import 'package:hazuki/shared/source_account/source_account_actions.dart';
import 'package:hazuki/shared/source_account/source_account_login.dart';
import 'package:hazuki/features/home/state/home_profile_controller.dart';

class HomeProfileFlow {
  const HomeProfileFlow({
    required this.context,
    required this.isMounted,
    required this.profileController,
    required this.sourceService,
    required this.imageService,
    required this.mediaChannel,
    required this.syncUserProfile,
  });

  final BuildContext context;
  final bool Function() isMounted;
  final HomeProfileController profileController;
  final SourceHomeGateway sourceService;
  final SourceImageGateway imageService;
  final MethodChannel mediaChannel;
  final Future<void> Function() syncUserProfile;

  Future<HomeLoginDialogProfile> handleLoginSubmit(
    String account,
    String password, {
    SourceAccountLoginOperation? loginOverride,
  }) async {
    final sourceKey = sourceService.activeSourceKey;
    final sourceRevision = sourceService.sourceRevision;
    final profile = await loginSourceAccountForDialog(
      sourceService: sourceService,
      account: account,
      password: password,
      loginOverride: loginOverride,
      afterLogin: () async {
        if (!isMounted()) {
          throw StateError('Home page disposed');
        }

        profileController.markAuthChanged();
        await syncUserProfile();
        if (!isMounted() || !context.mounted) {
          throw StateError('Home page disposed');
        }
      },
      usernameFallback: () => profileController.username,
      avatarUrlFallback: () => profileController.avatarUrl,
    );
    if (!isMounted() || !context.mounted) {
      throw StateError('Home page disposed');
    }
    if (sourceService.activeSourceKey != sourceKey ||
        sourceService.sourceRevision != sourceRevision ||
        !sourceService.isLogged) {
      throw const SourceLoginCancelled();
    }
    profileController.applyLoginProfile(
      username: profile.username,
      avatarUrl: profile.avatarUrl,
    );
    unawaited(showHazukiPrompt(context, l10n(context).homeLoginSuccess));
    return profile;
  }

  Future<void> showLoginDialog() async {
    final service = sourceService;
    final selectedSource = service.activeSourceKey;
    final methods = service is SourceInteractiveAccountGateway
        ? await (service as SourceInteractiveAccountGateway).loadLoginMethods()
        : <SourceLoginMethod>[];
    if (!isMounted() ||
        !context.mounted ||
        service.activeSourceKey != selectedSource) {
      return;
    }
    SourceLoginCancellation? attempt;
    await showHomeLoginDialog(
      context,
      loginMethods: methods,
      onDismissed: () => attempt?.cancel(),
      onLoginMethod: (account, password, method, present) {
        if (service.activeSourceKey != selectedSource) {
          throw const SourceLoginCancelled();
        }
        attempt?.cancel();
        final cancellation = attempt = SourceLoginCancellation();
        return handleLoginSubmit(
          account,
          password,
          loginOverride: ({required account, required password}) =>
              (service as SourceInteractiveAccountGateway).loginInteractive(
                account: account,
                password: password,
                method: method,
                cancellation: cancellation,
                present: present,
              ),
        );
      },
      initialUsername: profileController.username,
      initialAvatarUrl: (profileController.avatarUrl ?? '').trim(),
      firstUseText: profileController.firstUseText,
      onLogin: handleLoginSubmit,
      onLogoutTap: () {
        unawaited(logout());
      },
      onRequestSaveAvatar: promptSaveAvatar,
    );
  }

  Future<void> logout() async {
    if (!sourceService.isLogged) {
      return;
    }

    final confirmed = await showHomeLogoutConfirmDialog(context);
    if (!confirmed) {
      return;
    }

    await sourceService.logout();
    if (!isMounted() || !context.mounted) {
      return;
    }
    profileController.markLoggedOut();
    unawaited(syncUserProfile());
    unawaited(showHazukiPrompt(context, l10n(context).homeLoggedOut));
  }

  Future<void> promptSaveAvatar(String avatarUrl) async {
    final shouldSave = await showHomeSaveAvatarConfirmDialog(context);
    if (!shouldSave || !isMounted() || !context.mounted) {
      return;
    }
    await saveHomeAvatarToDownloads(
      context,
      mediaChannel: mediaChannel,
      imageUrl: avatarUrl,
      sourceService: imageService,
    );
  }

  Future<void> showAvatarCard() async {
    final avatarUrl = (profileController.avatarUrl ?? '').trim();
    await showHomeAvatarCard(
      context,
      avatarUrl: avatarUrl,
      username: profileController.username,
      firstUseText: profileController.firstUseText,
      onLogoutTap: () {
        Navigator.pop(context);
        unawaited(logout());
      },
      onRequestSaveAvatar: () => promptSaveAvatar(avatarUrl),
    );
  }
}
