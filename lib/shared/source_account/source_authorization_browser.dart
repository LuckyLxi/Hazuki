import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview_platform_interface/flutter_inappwebview_platform_interface.dart';
import 'package:flutter_inappwebview_windows/flutter_inappwebview_windows.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../services/source/account/source_browser_authorization.dart';
import '../../services/source/runtime/source_cookie_store.dart';

abstract interface class SourceAuthorizationCookieBrowser {
  Future<List<Map<String, Object?>>> readCookies(
    List<SourceAuthorizationCookieScope> scopes,
  );
}

abstract interface class SourceAuthorizationBrowser {
  Future<void> prepare(SourceBrowserAuthorizationSession session);
  Widget build(BuildContext context);
  Future<void> close();
}

SourceAuthorizationBrowser createSourceAuthorizationBrowser() =>
    switch (defaultTargetPlatform) {
      TargetPlatform.android => AndroidSourceAuthorizationBrowser(),
      TargetPlatform.windows => WindowsSourceAuthorizationBrowser(),
      _ => throw const SourceBrowserAuthorizationException(
        'login_browser_unavailable',
      ),
    };

class AndroidSourceAuthorizationBrowser
    implements SourceAuthorizationBrowser, SourceAuthorizationCookieBrowser {
  static const _host = MethodChannel('hazuki/browser_authorization');
  late SourceBrowserAuthorizationSession _session;
  MethodChannel? _events;

  @override
  Future<void> prepare(SourceBrowserAuthorizationSession session) async {
    _session = session;
    if (await _host.invokeMethod<bool>('prepare', {
          'cookies': session.options.cookieScopes.isNotEmpty,
        }) !=
        true) {
      throw const SourceBrowserAuthorizationException(
        'login_browser_update_webview',
      );
    }
    if (!session.isActive) return;
    _events = MethodChannel('hazuki/browser_authorization/${session.id}')
      ..setMethodCallHandler((call) async {
        if (call.method != 'event' || !session.isActive) return;
        final event = Map<String, dynamic>.from(call.arguments as Map);
        switch (event['type']) {
          case 'callback':
          case 'navigation':
            session.navigate(event['url'] as String, isMainFrame: true);
          case 'loading':
            session.setLoading(event['loading'] == true);
          case 'cancel':
            session.cancellation.cancel();
          case 'failure':
            session.fail('login_browser_load_failed');
          case 'externalFailure':
            session.fail('login_external_app_unavailable');
        }
      });
  }

  @override
  Future<List<Map<String, Object?>>> readCookies(
    List<SourceAuthorizationCookieScope> scopes,
  ) async {
    final raw = await _host.invokeListMethod<dynamic>('cookies', {
      'id': _session.id,
      'scopes': scopes.map((s) => s.toJson()).toList(),
    });
    final cookies = <Map<String, Object?>>[];
    for (final item in raw ?? const []) {
      final scopeUrl = item['url'] as String;
      final cookie = SourceCookie.parseSetCookie(
        item['cookie'] as String,
        scopeUrl,
        browserSnapshot: true,
      );
      if (cookie != null &&
          cookie.matches(Uri.parse(scopeUrl)) &&
          !cookie.isExpired(DateTime.now().millisecondsSinceEpoch)) {
        cookies.add({...cookie.toMap(), 'scopeUrl': scopeUrl});
      }
    }
    return cookies;
  }

  @override
  Widget build(BuildContext context) => AndroidView(
    viewType: 'hazuki/authorization_browser',
    creationParams: {
      'id': _session.id,
      'url': _session.options.url.toString(),
      'callbacks': _session.options.callbacks.map((c) => c.toJson()).toList(),
    },
    creationParamsCodec: const StandardMessageCodec(),
  );

  @override
  Future<void> close() async {
    _events?.setMethodCallHandler(null);
    await _host.invokeMethod<void>('close', _session.id);
  }
}

final _liveAuthorizationDirectories = <String>{};

Future<Directory> _authorizationDirectory() async => Directory(
  p.join((await getApplicationSupportDirectory()).path, 'plugin_authorization'),
);

/// Only generated session directories are eligible. Symlinks are never followed.
Future<void> cleanAuthorizationBrowserData() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) return;
  try {
    final base = await _authorizationDirectory();
    if (!await base.exists()) return;
    await for (final entry in base.list(followLinks: false)) {
      if (entry is Directory &&
          RegExp(r'^[a-f0-9]{32}$').hasMatch(p.basename(entry.path)) &&
          !_liveAuthorizationDirectories.contains(entry.path)) {
        try {
          await entry.delete(recursive: true);
        } on FileSystemException {
          // A departing WebView2 process may still own a handle. Retry next time.
        }
      }
    }
  } catch (_) {
    /* A cleanup failure never exposes browser paths or URLs. */
  }
}

class WindowsSourceAuthorizationBrowser
    implements SourceAuthorizationBrowser, SourceAuthorizationCookieBrowser {
  WindowsSourceAuthorizationBrowser({this.onControllerCreated});
  @visibleForTesting
  final void Function(PlatformInAppWebViewController controller)?
  onControllerCreated;
  WindowsWebViewEnvironment? _environment;
  Directory? _directory;
  SourceBrowserAuthorizationSession? _session;
  final _viewKey = GlobalKey<_WindowsAuthorizationViewState>();

  @override
  Future<void> prepare(SourceBrowserAuthorizationSession session) async {
    _session = session;
    // The package otherwise logs callback URLs and event arguments in debug mode.
    PlatformInAppWebViewController.debugLoggingSettings = DebugLoggingSettings(
      enabled: false,
    );
    PlatformWebViewEnvironment.debugLoggingSettings = DebugLoggingSettings(
      enabled: false,
    );
    if (await WindowsWebViewEnvironment.static().getAvailableVersion() ==
        null) {
      throw const SourceBrowserAuthorizationException(
        'login_browser_install_webview2',
      );
    }
    if (!session.isActive) return;
    await cleanAuthorizationBrowserData();
    final base = await _authorizationDirectory();
    _directory = Directory(p.join(base.path, session.id));
    _liveAuthorizationDirectories.add(_directory!.path);
    await _directory!.create(recursive: true);
    _environment = await WindowsWebViewEnvironment.static().create(
      settings: WebViewEnvironmentSettings(userDataFolder: _directory!.path),
    );
  }

  @override
  Future<List<Map<String, Object?>>> readCookies(
    List<SourceAuthorizationCookieScope> scopes,
  ) async {
    final controller = _viewKey.currentState?._controllers[null];
    if (controller == null) {
      throw const SourceBrowserAuthorizationException(
        'login_browser_cookie_unavailable',
      );
    }
    final result = <Map<String, Object?>>[];
    for (final scope in scopes) {
      // Read the owned view's browser context, including its HttpOnly cookies.
      // The package's environment-level manager uses a hidden regular-profile
      // view, which cannot see this session's InPrivate profile.
      final raw = await controller.callDevToolsProtocolMethod(
        methodName: 'Network.getCookies',
        parameters: {
          'urls': [scope.url],
        },
      );
      if (raw is! Map || raw['cookies'] is! List) {
        throw const SourceBrowserAuthorizationException(
          'login_browser_cookie_unavailable',
        );
      }
      for (final cookie in (raw['cookies'] as List).whereType<Map>()) {
        if (!scope.names.contains(cookie['name'])) continue;
        final expires = cookie['expires'];
        final value = SourceCookie(
          name: cookie['name'] as String,
          value: cookie['value'] as String,
          domain: cookie['domain'] as String,
          path: cookie['path'] as String,
          expiresAt: cookie['session'] == true || expires is! num
              ? null
              : (expires * 1000).round(),
          secure: cookie['secure'] == true,
          httpOnly: cookie['httpOnly'] == true,
          sameSite: cookie['sameSite']?.toString().toLowerCase(),
        );
        if (value.matches(Uri.parse(scope.url)) &&
            !value.isExpired(DateTime.now().millisecondsSinceEpoch)) {
          result.add({...value.toMap(), 'scopeUrl': scope.url});
        }
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) => _WindowsAuthorizationView(
    key: _viewKey,
    environment: _environment!,
    session: _session!,
    onControllerCreated: onControllerCreated,
  );

  @override
  Future<void> close() async {
    _viewKey.currentState?.close();
    // Let platform widgets dispose before releasing their shared environment.
    await WidgetsBinding.instance.endOfFrame;
    final environment = _environment;
    _environment = null;
    try {
      if (environment != null) await environment.dispose();
    } catch (_) {
      if (_directory != null) {
        _liveAuthorizationDirectories.remove(_directory!.path);
      }
      throw const SourceBrowserAuthorizationException(
        'login_browser_cleanup_failed',
      );
    }
    final directory = _directory;
    if (directory == null) return;
    _liveAuthorizationDirectories.remove(directory.path);
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        if (await directory.exists()) await directory.delete(recursive: true);
        break;
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
    }
  }
}

class _WindowsAuthorizationView extends StatefulWidget {
  const _WindowsAuthorizationView({
    super.key,
    required this.environment,
    required this.session,
    this.onControllerCreated,
  });
  final WindowsWebViewEnvironment environment;
  final SourceBrowserAuthorizationSession session;
  final void Function(PlatformInAppWebViewController controller)?
  onControllerCreated;
  @override
  State<_WindowsAuthorizationView> createState() =>
      _WindowsAuthorizationViewState();
}

class _WindowsAuthorizationViewState extends State<_WindowsAuthorizationView> {
  final _windows = <int?>[null];
  final _controllers = <int?, PlatformInAppWebViewController>{};
  bool _closed = false;

  void close() {
    if (_closed) return;
    _closed = true;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    // Widget disposal releases the native views. Controllers are disposed by the
    // package as well; only explicit close needs the early teardown above.
    _controllers.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _closed
      ? const SizedBox.shrink()
      : Stack(
          fit: StackFit.expand,
          children: [
            for (final id in _windows)
              _NativeWindowsAuthorizationView(
                key: ValueKey(id),
                params: WindowsInAppWebViewWidgetCreationParams(
                  windowId: id,
                  webViewEnvironment: widget.environment,
                  initialUrlRequest: id == null
                      ? URLRequest(
                          url: WebUri(widget.session.options.url.toString()),
                        )
                      : null,
                  initialSettings: InAppWebViewSettings(
                    incognito: true,
                    useShouldOverrideUrlLoading: true,
                    supportMultipleWindows: true,
                    javaScriptCanOpenWindowsAutomatically: false,
                    isInspectable: false,
                    allowFileAccess: false,
                    allowContentAccess: false,
                    allowFileAccessFromFileURLs: false,
                    allowUniversalAccessFromFileURLs: false,
                  ),
                  onWebViewCreated: (controller) {
                    _controllers[id] = controller;
                    if (id == null) {
                      widget.onControllerCreated?.call(controller);
                    }
                  },
                  shouldOverrideUrlLoading: (_, action) async =>
                      widget.session.navigate(
                        action.request.url?.toString() ?? '',
                        isMainFrame: action.isForMainFrame,
                      )
                      ? NavigationActionPolicy.ALLOW
                      : NavigationActionPolicy.CANCEL,
                  onLoadStart: (_, url) {
                    if (url != null) {
                      widget.session.navigate(
                        url.toString(),
                        isMainFrame: true,
                      );
                    }
                    widget.session.setLoading(true);
                  },
                  onLoadStop: (_, _) => widget.session.setLoading(false),
                  onReceivedError: (_, request, _) {
                    if (request.isForMainFrame == true) {
                      widget.session.fail('login_browser_load_failed');
                    }
                  },
                  onReceivedServerTrustAuthRequest: (_, _) async =>
                      ServerTrustAuthResponse(
                        action: ServerTrustAuthResponseAction.CANCEL,
                      ),
                  onPermissionRequest: (_, request) async => PermissionResponse(
                    resources: request.resources,
                    action: PermissionResponseAction.DENY,
                  ),
                  onCreateWindow: (_, action) async {
                    if (_closed ||
                        !widget.session.isActive ||
                        _windows.length >= 8) {
                      return false;
                    }
                    setState(() => _windows.add(action.windowId));
                    return true;
                  },
                  onCloseWindow: (_) {
                    if (id == null) {
                      widget.session.cancellation.cancel();
                      return;
                    }
                    if (mounted && !_closed) {
                      setState(() {
                        _windows.remove(id);
                        _controllers.remove(id);
                      });
                    }
                  },
                ),
              ),
          ],
        );
}

/// Own the federated Windows implementation directly. Android uses the native
/// Profile-aware backend and must not register a second, default-profile plugin.
class _NativeWindowsAuthorizationView extends StatefulWidget {
  const _NativeWindowsAuthorizationView({super.key, required this.params});
  final WindowsInAppWebViewWidgetCreationParams params;
  @override
  State<_NativeWindowsAuthorizationView> createState() =>
      _NativeWindowsAuthorizationViewState();
}

class _NativeWindowsAuthorizationViewState
    extends State<_NativeWindowsAuthorizationView> {
  late final _platform = WindowsInAppWebViewWidget(widget.params);
  @override
  Widget build(BuildContext context) => _platform.build(context);
  @override
  void dispose() {
    _platform.dispose();
    super.dispose();
  }
}
