import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/account/source_browser_authorization.dart';
import 'package:hazuki/services/source/account/source_login_interaction.dart';

Map<String, dynamic> options() => {
  'url': 'https://provider.example/authorize?state=private',
  'callbacks': [
    {
      'origin': 'https://site.example',
      'path': '/login',
      'requiredQueryKeys': ['token'],
    },
  ],
};

void main() {
  test(
    'manual cookie login stays open until every requested cookie exists',
    () async {
      final session = SourceBrowserAuthorizationSession(
        SourceBrowserAuthorizationOptions.parse({
          'url': 'https://site.example/login',
          'completion': 'manual',
          'cookieScopes': [
            {
              'url': 'https://site.example/account',
              'names': ['session'],
            },
          ],
        }),
        SourceLoginCancellation(),
      );
      addTearDown(session.dispose);
      session.readCookies = () async => [];
      await session.complete();
      expect(session.missingCookies, isTrue);
      expect(session.isActive, isTrue);
      session.readCookies = () async => [
        {
          'scopeUrl': 'https://site.example/account',
          'name': 'session',
          'value': 'mock',
          'httpOnly': true,
        },
      ];
      await session.complete();
      expect((await session.result)['status'], 'completed');
      expect(session.isActive, isFalse);
    },
  );
  test('cancelled cookie extraction cannot finish the login', () async {
    final cancellation = SourceLoginCancellation();
    final session = SourceBrowserAuthorizationSession(
      SourceBrowserAuthorizationOptions.parse({
        ...options(),
        'cookieScopes': [
          {
            'url': 'https://site.example/',
            'names': ['sid'],
          },
        ],
      }),
      cancellation,
    );
    addTearDown(session.dispose);
    final pending = Completer<List<Map<String, Object?>>>();
    session.readCookies = () => pending.future;
    final assertion = expectLater(
      session.result,
      throwsA(isA<SourceLoginCancelled>()),
    );
    final completing = session.complete(
      'https://site.example/login?token=mock',
    );
    cancellation.cancel();
    pending.complete([
      {'scopeUrl': 'https://site.example/', 'name': 'sid', 'value': 'late'},
    ]);
    await completing;
    await assertion;
    expect(session.state, SourceAuthorizationState.cancelled);
  });
  test('rejects malformed and non-HTTPS contracts without echoing values', () {
    for (final patch in [
      {'url': 'http://site.example/?token=private'},
      {'url': 'https://user:private@site.example/'},
      {'url': 'https://site.example\\@other.example/'},
      {'callbacks': []},
      {
        'callbacks': [
          {'origin': 'https://site.example/path', 'path': '/login'},
        ],
      },
      {
        'callbacks': [
          {'origin': 'https://site.example?token=private', 'path': '/login'},
        ],
      },
      {
        'callbacks': [
          {'origin': 'https://site.example', 'path': '//login'},
        ],
      },
      {
        'callbacks': [
          {'origin': 'https://site.example', 'path': '/login?token=private'},
        ],
      },
      {
        'callbacks': [
          {
            'origin': 'https://site.example',
            'path': '/login',
            'requiredQueryKeys': [1],
          },
        ],
      },
      {'timeoutMs': 29999},
      {'timeoutMs': 600001},
      {'timeoutMs': 30000.5},
    ]) {
      expect(
        () => SourceBrowserAuthorizationOptions.parse({...options(), ...patch}),
        throwsA(
          isA<SourceBrowserAuthorizationException>().having(
            (e) => e.toString(),
            'safe error',
            'login_invalid_browser_options',
          ),
        ),
      );
    }
    expect(
      SourceBrowserAuthorizationOptions.parse(options()).timeout,
      const Duration(minutes: 5),
    );
  });

  test(
    'only a complete exact top-level callback completes a session',
    () async {
      final cancellation = SourceLoginCancellation();
      final session = SourceBrowserAuthorizationSession(
        SourceBrowserAuthorizationOptions.parse(options()),
        cancellation,
      );
      addTearDown(session.dispose);
      for (final url in [
        'https://site.example.evil/login?token=x',
        'https://site.example:444/login?token=x',
        'https://site.example/login/other?token=x',
        'https://site.example/login',
        'https://site.example/login?token=',
      ]) {
        expect(session.navigate(url, isMainFrame: true), isTrue);
        expect(session.isActive, isTrue);
      }
      expect(session.navigate('file:///private', isMainFrame: true), isFalse);
      expect(session.navigate('weixin://auth', isMainFrame: true), isFalse);
      expect(
        session.navigate(
          'https://site.example/login?token=private',
          isMainFrame: false,
        ),
        isTrue,
      );
      expect(session.isActive, isTrue);
      expect(
        session.navigate(
          'https://SITE.example:443/login?token=private',
          isMainFrame: true,
        ),
        isFalse,
      );
      expect(await session.result, {
        'status': 'completed',
        'url': 'https://SITE.example:443/login?token=private',
      });
      expect(
        session.navigate(
          'https://site.example/login?token=late',
          isMainFrame: true,
        ),
        isFalse,
      );
      expect(session.state, SourceAuthorizationState.completed);
    },
  );

  testWidgets('timeout wins once and ignores later callbacks', (tester) async {
    final session = SourceBrowserAuthorizationSession(
      SourceBrowserAuthorizationOptions.parse({
        ...options(),
        'timeoutMs': 30000,
      }),
      SourceLoginCancellation(),
    );
    addTearDown(session.dispose);
    final result = expectLater(
      session.result,
      completion({'status': 'timeout'}),
    );
    await tester.pump(const Duration(seconds: 30));
    await result;
    expect(
      session.navigate(
        'https://site.example/login?token=late',
        isMainFrame: true,
      ),
      isFalse,
    );
  });

  test('cancellation wins over late success or failure', () async {
    final cancellation = SourceLoginCancellation();
    final session = SourceBrowserAuthorizationSession(
      SourceBrowserAuthorizationOptions.parse(options()),
      cancellation,
    );
    addTearDown(session.dispose);
    final result = expectLater(
      session.result,
      throwsA(isA<SourceLoginCancelled>()),
    );
    cancellation.cancel();
    session.fail('login_browser_load_failed');
    session.navigate(
      'https://site.example/login?token=late',
      isMainFrame: true,
    );
    await result;
    expect(session.state, SourceAuthorizationState.cancelled);
  });
}
