import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/interaction/source_ui_scope.dart';
import 'package:hazuki/services/source/interaction/source_ui_service.dart';
import 'package:hazuki/services/source/models/source_script_execution.dart';
import 'package:hazuki/services/source/runtime/source_js_bridge_cookie_capability.dart';
import 'package:hazuki/services/source/runtime/source_runtime_handle.dart';
import 'package:hazuki/services/source/runtime/source_script_engine.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Http implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString('ok', 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final service = SourceUiService.instance;
  late SourceRuntimeHandle handle;
  late SourceScriptEngine engine;
  late _Http http;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    service.setForeground(true);
    handle = SourceRuntimeHandle(
      sourceKey: 'anywhere',
      secureStorage: MemorySourceSecureSessionStorage(),
      ensureInitialized: (_) async {},
      notifyRuntimeStateChanged: (_) {},
    );
    engine = SourceScriptEngine(pluginId: 'anywhere');
    handle.runtime.engine = engine;
    http = _Http();
    handle.dio.httpClientAdapter = http;
    handle.httpGateway.configureCookieBridge();
    await handle.session.ensurePrefs();
    final bridge = SourceJsBridgeCookieCapability(activeHandle: () => handle);
    engine.setContextMessageHandler(
      (request, execution) => bridge.handleJsMessageForHandle(
        handle,
        request,
        execution: execution,
        runtimeId: engine.runtimeId,
      ),
    );
    await engine.execute(await rootBundle.loadString('assets/init.js'));
    await engine.execute(
      await rootBundle.loadString('assets/hazuki_plugin_sdk.js'),
    );
  });

  tearDown(() async {
    service.detach();
    service.setForeground(true);
    handle.requestDispose();
    await handle.whenDisposed;
  });

  for (final afterDispatch in [false, true]) {
    for (final restart in [false, true]) {
      for (final browser in [false, true]) {
        test(
          'owner cancellation blocks UI and HTTP: '
          'afterDispatch=$afterDispatch, restart=$restart, browser=$browser',
          () async {
            final owner = SourceUiOwner();
            addTearDown(owner.dispose);
            final shown = <SourceDialogSession>[];
            service.presenter = (dialog) async {
              shown.add(dialog);
              dialog.markShown();
              if (dialog.browserRequest == null) {
                dialog.action('confirm');
                await dialog.whenClosed;
              } else {
                dialog.completeBrowser({'status': 'completed'});
              }
            };
            late Future<dynamic> evaluation;
            final operation = owner.run(
              () => evaluation = engine.evaluate('''(async () => {
                try {
                  await ${browser ? "Hazuki.ui.openWebView({url:'https://site.example/'})" : "Hazuki.ui.alert({title:'Cancelled'})"};
                } catch (_) {}
                await Hazuki.http.get('https://site.example/late');
              })()'''),
            );
            final rejected = expectLater(
              operation,
              throwsA(isA<SourceUiCancelled>()),
            );
            if (afterDispatch) await Future<void>.value();
            if (restart) {
              owner.restart();
            } else {
              owner.dispose();
            }
            await rejected;
            await expectLater(evaluation, throwsA(anything));
            await engine.evaluate('0');
            expect(shown, isEmpty);
            expect(http.requests, isEmpty);
            expect(service.scopes, isEmpty);
            if (restart) {
              await owner.run(() => engine.evaluate('1'));
            }
          },
        );
      }
    }
  }

  test('callback cleanup still runs inside a cancelled caller scope', () async {
    await service.run(() async {
      final callback = await engine.evaluate('() => 1') as SourceScriptCallback;
      SourceUiScope.current!.cancel('user');
      await callback.free();
    });
    await engine.evaluate('0');
    expect(service.scopes, isEmpty);
  });

  test(
    'background calls and retained callbacks can show UI after HTTP',
    () async {
      final titles = <Object>[];
      service.presenter = (dialog) async {
        titles.add(dialog.model.title);
        dialog.markShown();
        dialog.action('confirm');
        await dialog.whenClosed;
      };
      await SourceUiScope.withoutInteraction(
        () => engine.evaluate("Hazuki.ui.alert({title:'Background'})"),
      );
      final callback =
          await service.run(
                () => engine.evaluate('''async () => {
        await Hazuki.delay(5);
        await Hazuki.http.get('https://site.example/before');
        await Hazuki.ui.alert({title:'Callback'});
        await Hazuki.http.get('https://site.example/after');
        return 42;
      }'''),
              )
              as SourceScriptCallback;
      expect(await callback.invoke([]), 42);
      await callback.free();
      expect(titles, ['Background', 'Callback']);
      expect(http.requests.map((r) => r.uri.path), ['/before', '/after']);
      // The worker's task-reference release follows completion over the same port.
      await engine.evaluate('0');
      expect(service.scopes, isEmpty);
    },
  );

  test(
    'native dialogs and WebViews from one task share the global queue',
    () async {
      final titles = <Object>[];
      service.presenter = (dialog) async {
        titles.add(dialog.model.title);
        dialog.markShown();
        if (dialog.browserRequest == null) {
          dialog.action('confirm');
        } else {
          dialog.completeBrowser({
            'status': 'completed',
            'url': 'https://site.example/verified',
            '_cookies': [
              {
                'scopeUrl': 'https://site.example/',
                'name': 'clearance',
                'value': 'synthetic',
                'domain': 'site.example',
                'path': '/',
                'secure': true,
                'httpOnly': true,
              },
            ],
            '_userAgent': 'Browser UA',
          });
        }
        await dialog.whenClosed;
      };
      final result =
          await engine.evaluate('''Promise.all([
      Hazuki.ui.alert({title:'First'}),
      Hazuki.ui.confirm({title:'Second'}),
      Hazuki.ui.openWebView({title:'Web',url:'https://site.example/',
        cookieScopes:[{url:'https://site.example/',names:['clearance']}]})
    ])''')
              as List;
      expect(titles, ['First', 'Second', 'Web']);
      expect(result[1], true);
      expect(result[2], {
        'status': 'completed',
        'url': 'https://site.example/verified',
      });
      expect(
        handle.cookieStore.buildHeader('https://site.example/'),
        'clearance=synthetic',
      );
      expect(handle.session.loadBrowserUserAgents(), {
        'https://site.example': 'Browser UA',
      });
    },
  );

  test(
    'background requests wait for foreground without spending UI budgets',
    () async {
      final ui = SourceUiService(
        queueTimeout: const Duration(milliseconds: 30),
        interactionTimeout: const Duration(milliseconds: 30),
      );
      addTearDown(ui.detach);
      var shown = false;
      ui.presenter = (dialog) async {
        shown = true;
        dialog.markShown();
        await dialog.whenClosed;
      };
      const task = SourceScriptExecution(
        taskId: 'background',
        pluginId: 'test',
        method: 'download',
      );
      ui.setForeground(false);
      expect(
        ui.handle({'method': 'ui_available'}, task, 'runtime', 'Test'),
        true,
      );
      final opening =
          ui.handle(
                {
                  'method': 'ui_open',
                  'options': {
                    'title': 'Background',
                    'content': [],
                    'buttons': [
                      {'id': 'ok', 'text': 'OK'},
                    ],
                  },
                },
                task,
                'runtime',
                'Test',
              )
              as Future;
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(shown, false);
      expect(ui.scopes.single.available, true);
      ui.checkExecution(task, 'runtime');
      ui.setForeground(true);
      final id = await opening;
      expect(shown, true);
      ui.handle({'method': 'ui_close', 'id': id}, task, 'runtime', 'Test');
      ui.releaseExecution(task, 'runtime');
      await Future<void>.delayed(Duration.zero);
      expect(ui.scopes, isEmpty);
    },
  );

  test(
    'an unawaited async callback can open UI after execute has returned',
    () async {
      service.presenter = (dialog) async {
        dialog.markShown();
        dialog.action('confirm');
        await dialog.whenClosed;
      };
      await engine.execute('''globalThis.detached = (async () => {
        await Hazuki.delay(20);
        await Hazuki.ui.alert({title:'Detached'});
        return 7;
      })()''');
      expect(await engine.evaluate('globalThis.detached'), 7);
    },
  );

  test(
    'generic WebView results wait until the app returns to foreground',
    () async {
      final showing = Completer<SourceDialogSession>();
      service.presenter = (dialog) async {
        dialog.markShown();
        showing.complete(dialog);
        await dialog.whenClosed;
      };
      var returned = false;
      final opening = engine
          .evaluate("Hazuki.ui.openWebView({url:'https://site.example/'})")
          .then((value) {
            returned = true;
            return value;
          });
      final dialog = await showing.future;
      service.setForeground(false);
      dialog.completeBrowser({
        'status': 'completed',
        'url': 'https://site.example/done',
      });
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(returned, false);
      service.setForeground(true);
      expect(await opening, {
        'status': 'completed',
        'url': 'https://site.example/done',
      });
    },
  );

  test(
    'WebView requests close across callbacks and await presenter cleanup',
    () async {
      final showing = Completer<SourceDialogSession>();
      final cleanup = Completer<void>();
      service.presenter = (dialog) async {
        dialog.markShown();
        showing.complete(dialog);
        await dialog.whenClosed;
        await cleanup.future;
      };
      final outcome = engine.evaluate(
        '''globalThis.webView = Hazuki.ui.openWebView({
        url:'https://site.example/',
        cookieScopes:[{url:'https://site.example/',names:['session']}]
      }); webView''',
      );
      final dialog = await showing.future;
      const otherPlugin = SourceScriptExecution(
        taskId: 'other',
        pluginId: 'other',
        method: 'close',
      );
      const samePlugin = SourceScriptExecution(
        taskId: 'other',
        pluginId: 'anywhere',
        method: 'close',
      );
      for (final (task, runtime) in [
        (otherPlugin, engine.runtimeId),
        (samePlugin, 'other-runtime'),
      ]) {
        expect(
          () => service.handle(
            {'method': 'ui_browser_close', 'id': dialog.id},
            task,
            runtime,
            'Test',
          ),
          throwsStateError,
        );
      }
      expect(dialog.isClosed, false);
      var closed = false;
      final closing = engine
          .evaluate('Promise.all([webView.close(), webView.close()])')
          .then((value) {
            closed = true;
            return value;
          });
      expect(await outcome, {'status': 'closed', 'reason': 'plugin'});
      expect(dialog.isClosed, true);
      expect(closed, false);
      expect(handle.cookieStore.buildHeader('https://site.example/'), isNull);
      expect(handle.session.loadBrowserUserAgents(), isEmpty);
      cleanup.complete();
      await closing;
      expect(closed, true);
      await engine.evaluate('webView.close()');
      expect(await engine.evaluate('webView'), {
        'status': 'closed',
        'reason': 'plugin',
      });
    },
  );

  test(
    'plugins can close queued WebViews before returning to foreground',
    () async {
      service.presenter = (_) async =>
          fail('closed queued WebView must never show');
      service.setForeground(false);
      expect(
        await engine.evaluate('''(async () => {
      globalThis.queuedWebView=Hazuki.ui.openWebView({url:'https://site.example/'});
      await queuedWebView.close();
      return true;
    })()'''),
        true,
      );
      service.setForeground(true);
      expect(await engine.evaluate('queuedWebView'), {
        'status': 'closed',
        'reason': 'plugin',
      });
      // Retained promises also retain their JS task context until released.
      await engine.evaluate('delete globalThis.queuedWebView');
      await engine.evaluate('0');
      expect(service.scopes, isEmpty);
    },
  );

  test(
    'WebView close preserves successful authorization and is repeatable',
    () async {
      service.presenter = (dialog) async {
        dialog.markShown();
        dialog.completeBrowser({
          'status': 'completed',
          'url': 'https://site.example/done',
        });
      };
      expect(
        await engine.evaluate('''(async () => {
      const view=Hazuki.ui.requestBrowserAuthorization({url:'https://site.example/',completion:'manual'});
      const result=await view;
      await view.close();
      await view.close();
      return result;
    })()'''),
        {'status': 'completed', 'url': 'https://site.example/done'},
      );
    },
  );

  test(
    'retiring runtime interactions still releases independent dialog scopes',
    () async {
      final shown = Completer<SourceDialogSession>();
      service.presenter = (dialog) async {
        dialog.markShown();
        shown.complete(dialog);
        await dialog.whenClosed;
      };
      const task = SourceScriptExecution(
        taskId: 'retired',
        pluginId: 'test',
        method: 'callback',
      );
      await service.handle(
        {
          'method': 'ui_open',
          'options': {
            'title': 'Retired',
            'content': [],
            'buttons': [
              {'id': 'ok', 'text': 'OK'},
            ],
          },
        },
        task,
        'retired-runtime',
        'Test',
      );
      expect((await shown.future).isClosed, false);
      service.closeRuntimeInteractions('retired-runtime');
      service.cancelRuntime('retired-runtime');
      await Future<void>.delayed(Duration.zero);
      expect(service.scopes, isEmpty);
    },
  );

  test(
    'runtime teardown cancels a queued WebView and a queued native dialog',
    () async {
      service.presenter = (_) async => fail('must wait for foreground');
      service.setForeground(false);
      final request = engine.evaluate('''Promise.all([
      Hazuki.ui.alert({title:'Queued'}),
      Hazuki.ui.openWebView({url:'https://site.example/'})
    ])''');
      final rejected = expectLater(request, throwsA(anything));
      while (service.scopes.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      handle.requestDispose();
      await rejected;
      await handle.whenDisposed;
      expect(service.scopes, isEmpty);
    },
  );
}
