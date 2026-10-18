import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/account/source_external_authorization.dart';
import 'package:hazuki/services/source/account/source_login_interaction.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('hazuki/external_authorization_test');
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'prepare') {
            return 'hazuki-auth-debug://authorize/${call.arguments['id']}';
          }
          return true;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  test('rejects executable protocols and URLs outside the declaration', () {
    for (final scheme in [
      'file',
      'javascript',
      'intent',
      'cmd',
      'shell',
      'ms-msdt',
    ]) {
      expect(
        () => SourceExternalAuthorizationOptions({
          'allowedSchemes': [scheme],
        }),
        throwsStateError,
      );
    }
    final options = SourceExternalAuthorizationOptions({
      'allowedSchemes': ['mock-provider'],
    });
    expect(options.allows('mock-provider://authorize?code=mock'), isTrue);
    expect(options.allows('other://authorize'), isFalse);
    expect(options.allows('mock-provider://user:secret@host'), isFalse);
  });
  test(
    'binds callback scheme, authority and random path and completes once',
    () async {
      final session = SourceExternalAuthorizationSession(
        SourceExternalAuthorizationOptions({
          'allowedSchemes': ['mock-provider'],
        }),
        SourceLoginCancellation(),
        channel: channel,
      );
      final callback = await session.prepare();
      final result = session.launch('mock-provider://login');
      expect(session.accept('$callback-wrong?code=x'), isFalse);
      expect(
        session.accept(callback.replaceFirst('authorize/', 'authorize.evil/')),
        isFalse,
      );
      expect(session.accept('$callback?code=mock'), isTrue);
      expect(session.accept('$callback?code=late'), isFalse);
      expect(await result, {
        'status': 'completed',
        'url': '$callback?code=mock',
      });
      await session.dispose();
    },
  );
  testWidgets('timeout and cancellation reject late callbacks', (tester) async {
    final token = SourceLoginCancellation();
    final session = SourceExternalAuthorizationSession(
      SourceExternalAuthorizationOptions({
        'allowedSchemes': ['mock-provider'],
        'timeoutMs': 30000,
      }),
      token,
      channel: channel,
    );
    final callback = await session.prepare();
    final result = session.launch('mock-provider://login');
    await tester.pump(const Duration(seconds: 30));
    expect(await result, {'status': 'timeout'});
    expect(session.accept(callback), isFalse);
    await session.dispose();
    final cancelled = SourceExternalAuthorizationSession(
      SourceExternalAuthorizationOptions({
        'allowedSchemes': ['mock-provider'],
      }),
      token,
      channel: channel,
    );
    await cancelled.prepare();
    final outcome = expectLater(
      cancelled.result,
      throwsA(isA<SourceLoginCancelled>()),
    );
    token.cancel();
    await outcome;
    await cancelled.dispose();
  });
}
