import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:flutter/foundation.dart';
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
  test(
    'task cancellation retains login cancellation and skips profile submission',
    () async {
      var submitted = false;
      final pending = loginSourceAccountForDialog(
        sourceService: _Account(),
        account: 'user',
        password: 'password',
        loginOverride: ({required account, required password}) async {
          throw const SourceTaskCancelled('attempt', SourceTaskStopReason.user);
        },
        afterLogin: () async {
          submitted = true;
        },
      );
      await expectLater(pending, throwsA(isA<SourceLoginCancelled>()));
      expect(submitted, isFalse);
    },
  );
}

class _Account extends ChangeNotifier implements SourceAccountGateway {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
