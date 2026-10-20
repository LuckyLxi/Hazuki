import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/app/source_runtime/source_plugin_dialog_presenter.dart';
import 'package:hazuki/services/source/interaction/source_ui_service.dart';
import 'package:hazuki/services/source/models/source_script_execution.dart';
import 'package:hazuki/services/source/account/source_browser_authorization.dart';
import 'package:hazuki/services/source/account/source_login_interaction.dart';
import 'package:hazuki/shared/source_account/source_authorization_browser.dart';
import 'package:hazuki/shared/source_account/source_browser_authorization_dialog.dart';

class _Browser
    implements SourceAuthorizationBrowser, SourceAuthorizationCookieBrowser {
  List<Map<String, Object?>> cookies = [];
  @override
  Future<String> readUserAgent() async => 'Synthetic browser UA';
  @override
  Future<List<Map<String, Object?>>> readCookies(
    List<SourceAuthorizationCookieScope> scopes,
  ) async => cookies;
  late SourceBrowserAuthorizationSession session;
  final ready = Completer<void>();
  bool closed = false;
  @override
  Future<void> prepare(SourceBrowserAuthorizationSession value) {
    session = value;
    return ready.future.then((_) => session.setLoading(false));
  }

  @override
  Widget build(BuildContext context) => const Text('Browser content');
  @override
  Future<void> close() async {
    closed = true;
  }
}

void main() {
  for (final factoryFailure in [false, true]) {
    testWidgets('global browser preserves failures and permits retry: '
        'factoryFailure=$factoryFailure', (tester) async {
      final key = GlobalKey<NavigatorState>();
      final failedBrowser = _Browser()..ready.complete();
      final retryBrowser = _Browser()..ready.complete();
      var attempts = 0;
      final code = factoryFailure
          ? 'login_browser_unavailable'
          : 'login_browser_load_failed';
      final presenter = SourcePluginDialogPresenter(
        key,
        browserFactory: () {
          if (attempts++ == 0) {
            if (factoryFailure) {
              throw SourceBrowserAuthorizationException(code);
            }
            return failedBrowser;
          }
          return retryBrowser;
        },
      );
      addTearDown(presenter.dispose);
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: key,
          navigatorObservers: [presenter],
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: Text('Home')),
        ),
      );
      const execution = SourceScriptExecution(
        taskId: 'browser-retry',
        pluginId: 'test',
        method: 'download',
      );
      final service = SourceUiService.instance;
      Future<dynamic> open() => service.runBrowserAuthorization(
        () => service.handle(
          {
            'method': 'ui_browser',
            'options': {'url': 'https://site.example/', 'completion': 'manual'},
          },
          execution,
          'retry-runtime',
          'Test',
        ),
        execution: execution,
        runtimeId: 'retry-runtime',
        timeout: const Duration(minutes: 5),
      );
      final rejected = expectLater(
        open(),
        throwsA(
          isA<SourceBrowserAuthorizationException>().having(
            (error) => error.code,
            'code',
            code,
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (!factoryFailure) failedBrowser.session.fail(code);
      await tester.pumpAndSettle();
      await rejected;
      expect(service.scopes.single.available, true);
      final retry = open();
      await tester.pumpAndSettle();
      expect(find.text('Browser content'), findsOneWidget);
      await retryBrowser.session.complete();
      await tester.pumpAndSettle();
      expect((await retry as Map)['status'], 'completed');
      expect(find.text('Home'), findsOneWidget);
      expect(retryBrowser.closed, true);
      expect(tester.takeException(), isNull);
      service.releaseExecution(execution, 'retry-runtime');
      await tester.pumpAndSettle();
      expect(service.scopes, isEmpty);
    });
  }

  for (final covered in [false, true]) {
    testWidgets(
      'global WebView completes without a login scope, covered: $covered',
      (tester) async {
        final key = GlobalKey<NavigatorState>();
        final browser = _Browser()..ready.complete();
        final presenter = SourcePluginDialogPresenter(
          key,
          browserFactory: () => browser,
        );
        addTearDown(presenter.dispose);
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: key,
            navigatorObservers: [presenter],
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: Text('Home')),
          ),
        );
        const execution = SourceScriptExecution(
          taskId: 'global-web',
          pluginId: 'test',
          method: 'download',
        );
        final result =
            SourceUiService.instance.handle(
                  {
                    'method': 'ui_browser',
                    'options': {
                      'title': 'Verify website',
                      'url': 'https://site.example/',
                      'completion': 'manual',
                    },
                  },
                  execution,
                  'web-runtime',
                  'Test',
                )
                as Future;
        await tester.pumpAndSettle();
        expect(find.text('Browser content'), findsOneWidget);
        if (covered) {
          unawaited(
            key.currentState!.push(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('New page')),
              ),
            ),
          );
          await tester.pumpAndSettle();
        }
        browser.session.navigate(
          'https://site.example/verified',
          isMainFrame: true,
        );
        if (covered) {
          await browser.session.complete();
        } else {
          await tester.tap(find.text('Complete login'));
        }
        await tester.pumpAndSettle();
        expect(await result, {
          'status': 'completed',
          'url': 'https://site.example/verified',
        });
        expect(browser.closed, true);
        expect(find.text(covered ? 'New page' : 'Home'), findsOneWidget);
        expect(tester.takeException(), isNull);
        SourceUiService.instance.releaseExecution(execution, 'web-runtime');
      },
    );
  }

  Future<BuildContext> mount(WidgetTester tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (c) {
            context = c;
            return const Scaffold(body: Text('Home'));
          },
        ),
      ),
    );
    return context;
  }

  Map<String, dynamic> request() => {
    'url': 'https://provider.example/auth?secret=private',
    'sourceName': 'Plugin',
    'callbacks': [
      {
        'origin': 'https://site.example',
        'path': '/done',
        'requiredQueryKeys': ['token'],
      },
    ],
  };
  testWidgets(
    'manual completion keeps the browser open for missing cookies and closes before returning',
    (tester) async {
      final context = await mount(tester);
      final browser = _Browser()..ready.complete();
      final future = showSourceBrowserAuthorization(
        context,
        {
          'url': 'https://site.example/login',
          'completion': 'manual',
          'cookieScopes': [
            {
              'url': 'https://site.example/account',
              'names': ['sid'],
            },
          ],
        },
        SourceLoginCancellation(),
        browserFactory: () => browser,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Complete login'));
      await tester.pumpAndSettle();
      expect(browser.closed, isFalse);
      expect(find.textContaining('Required login cookies'), findsOneWidget);
      browser.cookies = [
        {
          'scopeUrl': 'https://site.example/account',
          'name': 'sid',
          'value': 'synthetic',
          'httpOnly': true,
        },
      ];
      await tester.tap(find.text('Complete login'));
      await tester.pumpAndSettle();
      expect((await future as Map)['status'], 'completed');
      expect(browser.closed, isTrue);
    },
  );

  testWidgets(
    'renders only the origin and releases browser before returning callback',
    (tester) async {
      final context = await mount(tester);
      final browser = _Browser()..ready.complete();
      final future = showSourceBrowserAuthorization(
        context,
        request(),
        SourceLoginCancellation(),
        browserFactory: () => browser,
      );
      await tester.pumpAndSettle();
      expect(find.text('https://provider.example'), findsOneWidget);
      expect(find.textContaining('private'), findsNothing);
      expect(find.text('Browser content'), findsOneWidget);
      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      browser.session.navigate(
        'https://site.example/done?token=private',
        isMainFrame: true,
      );
      await tester.pumpAndSettle();
      expect(await future, {
        'status': 'completed',
        'url': 'https://site.example/done?token=private',
      });
      expect(browser.closed, isTrue);
      expect(find.text('Home'), findsOneWidget);
    },
  );

  testWidgets(
    'cancellation during preparation cleans late platform resources',
    (tester) async {
      final context = await mount(tester);
      final browser = _Browser();
      final cancellation = SourceLoginCancellation();
      final future = showSourceBrowserAuthorization(
        context,
        request(),
        cancellation,
        browserFactory: () => browser,
      );
      final rejected = expectLater(
        future,
        throwsA(isA<SourceLoginCancelled>()),
      );
      await tester.pump();
      cancellation.cancel();
      await tester.pump(const Duration(milliseconds: 300));
      browser.ready.complete();
      await tester.pumpAndSettle();
      await rejected;
      expect(browser.closed, isTrue);
      expect(find.text('Browser content'), findsNothing);
    },
  );

  testWidgets(
    'missing runtime displays installation action without leaking platform errors',
    (tester) async {
      final context = await mount(tester);
      final browser = _Browser();
      final cancellation = SourceLoginCancellation();
      final future = showSourceBrowserAuthorization(
        context,
        request(),
        cancellation,
        browserFactory: () => browser,
      );
      final rejected = expectLater(
        future,
        throwsA(isA<SourceLoginCancelled>()),
      );
      browser.ready.completeError(
        const SourceBrowserAuthorizationException(
          'login_browser_install_webview2',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Open installation page'), findsOneWidget);
      expect(find.text('Browser content'), findsNothing);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await rejected;
      expect(browser.closed, isTrue);
    },
  );

  test(
    'unsupported Android profile returns a safe error and never creates a view',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('hazuki/browser_authorization'),
            (call) async => false,
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('hazuki/browser_authorization'),
              null,
            ),
      );
      final session = SourceBrowserAuthorizationSession(
        SourceBrowserAuthorizationOptions.parse(request()),
        SourceLoginCancellation(),
      );
      final result = session.result.catchError(
        (Object _) => <String, Object>{},
      );
      final backend = AndroidSourceAuthorizationBrowser();
      await expectLater(
        backend.prepare(session),
        throwsA(
          isA<SourceBrowserAuthorizationException>().having(
            (e) => e.code,
            'safe code',
            'login_browser_update_webview',
          ),
        ),
      );
      await backend.close();
      session.dispose();
      await result;
    },
  );

  test(
    'Android external app launch failure ends the pending browser session',
    () async {
      const channel = MethodChannel('hazuki/browser_authorization');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async => true);
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final session = SourceBrowserAuthorizationSession(
        SourceBrowserAuthorizationOptions.parse(request()),
        SourceLoginCancellation(),
      );
      final backend = AndroidSourceAuthorizationBrowser();
      await backend.prepare(session);
      final rejected = expectLater(
        session.result,
        throwsA(
          isA<SourceBrowserAuthorizationException>().having(
            (e) => e.code,
            'safe code',
            'login_external_app_unavailable',
          ),
        ),
      );
      final done = Completer<void>();
      await messenger.handlePlatformMessage(
        'hazuki/browser_authorization/${session.id}',
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('event', {'type': 'externalFailure'}),
        ),
        (_) => done.complete(),
      );
      await done.future;
      await rejected;
      expect(session.isActive, isFalse);
      await backend.close();
      session.dispose();
    },
  );

  test(
    'owned Android callback is one-shot and close releases its channel',
    () async {
      const channel = MethodChannel('hazuki/browser_authorization');
      final calls = <String>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        if (call.method == 'userAgent') {
          expect(call.arguments['id'], isA<String>());
          return 'Actual Android UA';
        }
        return true;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final session = SourceBrowserAuthorizationSession(
        SourceBrowserAuthorizationOptions.parse(request()),
        SourceLoginCancellation(),
      );
      final backend = AndroidSourceAuthorizationBrowser();
      await backend.prepare(session);
      expect(await backend.readUserAgent(), 'Actual Android UA');
      Future<void> event(String value) async {
        final done = Completer<void>();
        await messenger.handlePlatformMessage(
          'hazuki/browser_authorization/${session.id}',
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('event', {'type': 'callback', 'url': value}),
          ),
          (_) => done.complete(),
        );
        await done.future;
      }

      await event('https://site.example/done?token=synthetic');
      await event('https://site.example/done?token=late');
      expect(await session.result, {
        'status': 'completed',
        'url': 'https://site.example/done?token=synthetic',
      });
      await backend.close();
      expect(calls, ['prepare', 'userAgent', 'close']);
      session.dispose();
    },
  );
}
