import 'package:hazuki/services/source/source_capabilities.dart';

import 'source_account_actions.dart';

typedef SourceAccountLoginOperation =
    Future<void> Function({required String account, required String password});

typedef SourceAccountAvatarLoader = Future<String?> Function();

Future<HomeLoginDialogProfile> loginSourceAccountForDialog({
  required SourceAccountGateway sourceService,
  required String account,
  required String password,
  SourceAccountLoginOperation? loginOverride,
  SourceTaskOrigin? taskOrigin,
  Future<void> Function()? afterLogin,
  String Function()? usernameFallback,
  String? Function()? avatarUrlFallback,
}) async {
  try {
    return await buildSourceAccountDialogProfileAfterLogin(
      account: account,
      password: password,
      login:
          loginOverride ??
          ({required account, required password}) => sourceService.login(
            account: account,
            password: password,
            taskOrigin: taskOrigin,
          ),
      currentAccount: () => sourceService.currentAccount,
      loadAvatarUrl: () =>
          sourceService.loadCurrentAvatarUrl(taskOrigin: taskOrigin),
      afterLogin: afterLogin,
      usernameFallback: usernameFallback,
      avatarUrlFallback: avatarUrlFallback,
    );
  } on SourceTaskCancelled {
    throw const SourceLoginCancelled();
  }
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
