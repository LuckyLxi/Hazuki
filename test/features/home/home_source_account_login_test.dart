import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/shared/source_account/source_account_login.dart';

void main() {
  test('builds dialog profile from shared source login flow', () async {
    final calls = <String>[];
    var currentAccount = 'display-name';

    final profile = await buildSourceAccountDialogProfileAfterLogin(
      account: 'user',
      password: 'pass',
      login: ({required account, required password}) async {
        calls.add('$account:$password');
      },
      currentAccount: () => currentAccount,
      loadAvatarUrl: () async => 'https://example.com/avatar.jpg',
    );

    expect(calls, ['user:pass']);
    expect(profile.username, 'display-name');
    expect(profile.avatarUrl, 'https://example.com/avatar.jpg');

    currentAccount = '';
    final fallbackProfile = await buildSourceAccountDialogProfileAfterLogin(
      account: 'next-user',
      password: 'next-pass',
      login: ({required account, required password}) async {},
      currentAccount: () => null,
      loadAvatarUrl: () async => 'https://example.com/ignored.jpg',
      usernameFallback: () => 'controller-name',
      avatarUrlFallback: () => 'https://example.com/cached.jpg',
    );

    expect(fallbackProfile.username, 'controller-name');
    expect(fallbackProfile.avatarUrl, 'https://example.com/cached.jpg');
  });
}
