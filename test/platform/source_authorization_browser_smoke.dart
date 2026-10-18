// Native Windows smoke test. Requires network access to https://example.com.
// Run: flutter run -d windows -t test/platform/source_authorization_browser_smoke.dart
// Uses synthetic data only; writes a boolean report to build/ and exits.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview_platform_interface/flutter_inappwebview_platform_interface.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:hazuki/services/source/account/source_browser_authorization.dart';
import 'package:hazuki/services/source/account/source_login_interaction.dart';
import 'package:hazuki/shared/source_account/source_authorization_browser.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final report = <String, Object>{};
  final backends = <WindowsSourceAuthorizationBrowser>[];
  final sessions = <SourceBrowserAuthorizationSession>[];
  try {
    for (var attempt = 0; attempt < 2; attempt++) {
      final ready = Completer<PlatformInAppWebViewController>();
      final session = SourceBrowserAuthorizationSession(
        SourceBrowserAuthorizationOptions.parse({
          'url': 'https://example.com/',
          'callbacks': [
            {
              'origin': 'https://example.com',
              'path': '/hazuki_callback',
              'requiredQueryKeys': ['token'],
            },
          ],
        }),
        SourceLoginCancellation(),
      );
      // Cancellation in teardown is expected and must not become an unhandled error.
      unawaited(session.result.catchError((Object _) => <String, Object>{}));
      sessions.add(session);
      final backend = WindowsSourceAuthorizationBrowser(
        onControllerCreated: ready.complete,
      );
      backends.add(backend);
      await backend.prepare(session);
      runApp(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                for (final browser in backends)
                  Expanded(child: Builder(builder: browser.build)),
              ],
            ),
          ),
        ),
      );
      final controller = await ready.future.timeout(
        const Duration(seconds: 30),
      );
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      while (session.loading &&
          session.isActive &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      if (!session.isActive || session.loading) {
        throw StateError('page_not_ready');
      }
      if (attempt == 0) {
        final mockLoaded = Completer<void>();
        unawaited(mockLoaded.future.catchError((Object _) {}));
        await controller.addDevToolsProtocolEventListener(
          eventName: 'Page.loadEventFired',
          callback: (_) {
            if (!mockLoaded.isCompleted) mockLoaded.complete();
          },
        );
        await controller.callDevToolsProtocolMethod(methodName: 'Page.enable');
        final html = await File(
          'test/platform/fixtures/browser_authorization/login.html',
        ).readAsBytes();
        await controller.addDevToolsProtocolEventListener(
          eventName: 'Fetch.requestPaused',
          callback: (data) async {
            try {
              await controller.callDevToolsProtocolMethod(
                methodName: 'Fetch.fulfillRequest',
                parameters: {
                  'requestId': data['requestId'],
                  'responseCode': 200,
                  'responseHeaders': [
                    {
                      'name': 'Content-Type',
                      'value': 'text/html; charset=utf-8',
                    },
                    {
                      'name': 'Set-Cookie',
                      'value':
                          'hazukiHttpOnly=synthetic; Path=/; Secure; HttpOnly; SameSite=Strict; Max-Age=600',
                    },
                  ],
                  'body': base64Encode(html),
                },
              );
            } catch (_) {
              if (!mockLoaded.isCompleted) {
                mockLoaded.completeError(StateError('mock_page_failed'));
              }
            }
          },
        );
        await controller.callDevToolsProtocolMethod(
          methodName: 'Fetch.enable',
          parameters: {
            'patterns': [
              {
                'urlPattern': 'https://example.com/hazuki_mock*',
                'requestStage': 'Request',
              },
            ],
          },
        );
        await controller.loadUrl(
          urlRequest: URLRequest(
            url: WebUri('https://example.com/hazuki_mock_login'),
          ),
        );
        await mockLoaded.future.timeout(const Duration(seconds: 20));
        report['localMockPageLoaded'] = true;
        final visible = await controller.callDevToolsProtocolMethod(
          methodName: 'Network.getCookies',
          parameters: {
            'urls': ['https://example.com/'],
          },
        );
        report['cookieVisibleInView'] =
            visible is Map &&
            (visible['cookies'] as List).any(
              (c) => c['name'] == 'hazukiHttpOnly',
            );
        final exported = await backend.readCookies(const [
          SourceAuthorizationCookieScope('https://example.com/', [
            'hazukiHttpOnly',
          ]),
        ]);
        report['cookieFound'] = exported.length == 1;
        if (exported.length == 1) {
          report['cookieSecure'] = exported.single['secure'] == true;
          report['cookieHttpOnly'] = exported.single['httpOnly'] == true;
          report['cookieHostOnly'] = exported.single['hostOnly'] == true;
          report['cookieSameSite'] = exported.single['sameSite'] == 'strict';
          report['cookieExpiry'] =
              (exported.single['expiresAt'] as int?) != null &&
              (exported.single['expiresAt'] as int) >
                  DateTime.now().millisecondsSinceEpoch;
        }
        report['cookieAttributes'] =
            exported.length == 1 &&
            exported.single['secure'] == true &&
            exported.single['httpOnly'] == true &&
            exported.single['hostOnly'] == true &&
            exported.single['sameSite'] == 'strict' &&
            (exported.single['expiresAt'] as int) >
                DateTime.now().millisecondsSinceEpoch;
        if (report['cookieAttributes'] != true) {
          throw StateError('cookie_attributes_failed');
        }
        final value = await controller.callAsyncJavaScript(
          functionBody: '''
          document.cookie='hazukiIsolation=synthetic; path=/; Secure; SameSite=Lax';
          localStorage.setItem('hazukiIsolation','synthetic');
          await new Promise((resolve,reject)=>{const r=indexedDB.open('hazukiIsolation',1);
            r.onupgradeneeded=()=>r.result.createObjectStore('data');
            r.onsuccess=()=>{r.result.close();resolve(true)};r.onerror=reject});
          const c=await caches.open('hazukiIsolation');
          await c.put('/hazuki_cache',new Response('synthetic'));
          return true;
        ''',
        );
        if (value?.value != true) throw StateError('storage_setup_failed');
        report['storageWritten'] = true;
      } else {
        report['httpOnlyCookieIsolated'] = (await backend.readCookies(const [
          SourceAuthorizationCookieScope('https://example.com/', [
            'hazukiHttpOnly',
          ]),
        ])).isEmpty;
        if (report['httpOnlyCookieIsolated'] != true) {
          throw StateError('http_only_isolation_failed');
        }
        final value = await controller.callAsyncJavaScript(
          functionBody: '''
          return {cookies:!document.cookie.includes('hazukiIsolation'),
            localStorage:localStorage.getItem('hazukiIsolation')===null,
            indexedDB:!(await indexedDB.databases()).some(d=>d.name==='hazukiIsolation'),
            cache:!(await caches.keys()).includes('hazukiIsolation')};
        ''',
        );
        final checks = Map<String, dynamic>.from(value?.value as Map);
        for (final key in ['cookies', 'localStorage', 'indexedDB', 'cache']) {
          report[key] = checks[key] == true;
          if (checks[key] != true) throw StateError('storage_isolation_failed');
        }
        await controller.loadUrl(
          urlRequest: URLRequest(
            url: WebUri('https://example.com/hazuki_callback?token=synthetic'),
          ),
        );
        final result = await session.result.timeout(
          const Duration(seconds: 10),
        );
        report['callbackIntercepted'] = result['status'] == 'completed';
      }
    }
    report['passed'] = true;
  } catch (_) {
    report['passed'] = false;
  } finally {
    for (final backend in backends.reversed) {
      try {
        await backend.close();
      } catch (_) {
        report['cleanupFailed'] = true;
      }
    }
    for (final session in sessions) {
      session.dispose();
    }
    await cleanAuthorizationBrowserData();
    final base = (await getApplicationSupportDirectory()).path;
    report['directoriesCleaned'] = false;
    for (var attempt = 0; attempt < 20; attempt++) {
      final remaining = await Future.wait(
        sessions.map(
          (session) => Directory(
            p.join(base, 'plugin_authorization', session.id),
          ).exists(),
        ),
      );
      if (!remaining.any((exists) => exists)) {
        report['directoriesCleaned'] = true;
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await cleanAuthorizationBrowserData();
    }
    final output = File('build/browser-auth-native-smoke.json');
    await output.parent.create(recursive: true);
    await output.writeAsString(jsonEncode(report));
  }
  exit(
    report['passed'] == true &&
            report['cleanupFailed'] != true &&
            report['directoriesCleaned'] == true
        ? 0
        : 1,
  );
}
