import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';
import '../../services/hazuki_source_service.dart';
import '../../widgets/widgets.dart';
import 'home_profile_actions.dart';
import 'home_profile_controller.dart';

class HomeProfileFlow {
  const HomeProfileFlow({
    required this.context,
    required this.isMounted,
    required this.profileController,
    required this.mediaChannel,
    required this.syncUserProfile,
  });

  final BuildContext context;
  final bool Function() isMounted;
  final HomeProfileController profileController;
  final MethodChannel mediaChannel;
  final Future<void> Function() syncUserProfile;

  Future<HomeLoginDialogProfile> handleLoginSubmit(
    String account,
    String password,
  ) async {
    await HazukiSourceService.instance.login(
      account: account,
      password: password,
    );

    if (!isMounted()) {
      throw StateError('Home page disposed');
    }

    profileController.markAuthChanged();
    await syncUserProfile();
    if (!isMounted() || !context.mounted) {
      throw StateError('Home page disposed');
    }

    unawaited(showHazukiPrompt(context, l10n(context).homeLoginSuccess));
    return HomeLoginDialogProfile(
      username:
          HazukiSourceService.instance.currentAccount ??
          profileController.username,
      avatarUrl: (profileController.avatarUrl ?? '').trim(),
    );
  }

  Future<void> showLoginDialog() async {
    await showHomeLoginDialog(
      context,
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
    if (!HazukiSourceService.instance.isLogged) {
      return;
    }

    final confirmed = await showHomeLogoutConfirmDialog(context);
    if (!confirmed) {
      return;
    }

    await HazukiSourceService.instance.logout();
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
