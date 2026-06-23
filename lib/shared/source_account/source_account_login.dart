import 'package:hazuki/services/hazuki_source_service.dart';

import 'source_account_actions.dart';

typedef SourceAccountLoginOperation =
    Future<void> Function({required String account, required String password});

typedef SourceAccountAvatarLoader = Future<String?> Function();

Future<HomeLoginDialogProfile> loginSourceAccountForDialog({
  required HazukiSourceService sourceService,
  required String account,
  required String password,
  Future<void> Function()? afterLogin,
  String Function()? usernameFallback,
  String? Function()? avatarUrlFallback,
}) {
  return buildSourceAccountDialogProfileAfterLogin(
    account: account,
    password: password,
    login: sourceService.login,
    currentAccount: () => sourceService.currentAccount,
    loadAvatarUrl: sourceService.loadCurrentAvatarUrl,
    afterLogin: afterLogin,
    usernameFallback: usernameFallback,
    avatarUrlFallback: avatarUrlFallback,
  );
}

Future<HomeLoginDialogProfile> buildSourceAccountDialogProfileAfterLogin({
  required String account,
  required String password,
  required SourceAccountLoginOperation login,
  required String? Function() currentAccount,
  required SourceAccountAvatarLoader loadAvatarUrl,
  Future<void> Function()? afterLogin,
  String Function()? usernameFallback,
  String? Function()? avatarUrlFallback,
}) async {
  await login(account: account, password: password);
  await afterLogin?.call();

  final fallbackAvatarUrl = avatarUrlFallback?.call()?.trim() ?? '';
  final avatarUrl = fallbackAvatarUrl.isNotEmpty
      ? fallbackAvatarUrl
      : ((await loadAvatarUrl()) ?? '').trim();

  return HomeLoginDialogProfile(
    username: currentAccount() ?? usernameFallback?.call() ?? account,
    avatarUrl: avatarUrl,
  );
}
