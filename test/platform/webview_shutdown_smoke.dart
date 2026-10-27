// Build with: flutter build windows --release -t test/platform/webview_shutdown_smoke.dart
// Run with and without --dispose-views, and with --quit-loop. Check both the JSON
// report and the process exit code: exit() bypasses native plugin destruction.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview_platform_interface/flutter_inappwebview_platform_interface.dart';
import 'package:flutter_inappwebview_windows/flutter_inappwebview_windows.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  final report = <String, Object>{};
  final directory = await Directory.systemTemp.createTemp('hazuki-shutdown-');
  report['userDataFolder'] = directory.path;
  try {
    final environment = await WindowsWebViewEnvironment.static().create(
      settings: WebViewEnvironmentSettings(userDataFolder: directory.path),
    );
    final headlessLoaded = Completer<void>();
    final headless = WindowsHeadlessInAppWebView(
      WindowsHeadlessInAppWebViewCreationParams(
        webViewEnvironment: environment,
        initialUrlRequest: URLRequest(url: WebUri('about:blank')),
        onLoadStop: (_, _) {
          if (!headlessLoaded.isCompleted) headlessLoaded.complete();
        },
      ),
    );
    await headless.run();
    await headlessLoaded.future.timeout(const Duration(seconds: 30));
    report['headlessLoaded'] = true;

    final viewLoaded = Completer<PlatformInAppWebViewController>();
    final view = WindowsInAppWebViewWidget(
      WindowsInAppWebViewWidgetCreationParams(
        webViewEnvironment: environment,
        initialUrlRequest: URLRequest(url: WebUri('about:blank')),
        onLoadStop: (controller, _) {
          if (!viewLoaded.isCompleted) viewLoaded.complete(controller);
        },
      ),
    );
    runApp(
      MaterialApp(
        home: Scaffold(body: Builder(builder: view.build)),
      ),
    );
    final controller = await viewLoaded.future.timeout(
      const Duration(seconds: 30),
    );
    report['viewLoaded'] =
        await controller.evaluateJavascript(source: '1 + 1') == 2;
    final disposeViews = arguments.contains('--dispose-views');
    if (disposeViews) {
      runApp(const SizedBox.shrink());
      await WidgetsBinding.instance.endOfFrame;
      view.dispose();
      await headless.dispose();
      await environment.dispose();
    }
    report['viewsDisposedBeforeClose'] = disposeViews;
    report['passed'] = report['viewLoaded'] == true;
  } catch (error, stack) {
    report['passed'] = false;
    report['error'] = error.toString();
    report['stack'] = stack.toString();
  } finally {
    await File(
      'build/webview-shutdown-native-smoke.json',
    ).writeAsString(jsonEncode(report));
    // Exercise both WM_CLOSE and quitting the loop before window destruction.
    if (arguments.contains('--quit-loop')) {
      await windowManager.destroy();
    } else {
      await windowManager.close();
    }
  }
}
