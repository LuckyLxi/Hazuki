import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'source_login_interaction.dart';

/// Never includes URLs or platform error descriptions in diagnostic output.
class SourceBrowserAuthorizationException implements Exception {
  const SourceBrowserAuthorizationException(this.code);
  final String code;
  @override
  String toString() => code;
}

Uri? authorizationHttpsUri(Object? value) {
  if (value is! String || value.contains(RegExp(r'[\s\\]'))) return null;
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return uri;
}

class SourceAuthorizationCallback {
  const SourceAuthorizationCallback(
    this.origin,
    this.path,
    this.requiredQueryKeys,
  );
  final String origin;
  final String path;
  final List<String> requiredQueryKeys;

  bool matches(Uri uri) =>
      uri.origin == origin &&
      uri.path == path &&
      requiredQueryKeys.every(
        (key) => uri.queryParametersAll[key]?.any((v) => v.isNotEmpty) == true,
      );

  Map<String, Object> toJson() => {
    'origin': origin,
    'path': path,
    'requiredQueryKeys': requiredQueryKeys,
  };
}

class SourceBrowserAuthorizationOptions {
  const SourceBrowserAuthorizationOptions({
    required this.url,
    required this.callbacks,
    required this.timeout,
    this.title,
    this.manual = false,
    this.cookieScopes = const [],
  });
  final Uri url;
  final List<SourceAuthorizationCallback> callbacks;
  final Duration timeout;
  final Object? title;
  final bool manual;
  final List<SourceAuthorizationCookieScope> cookieScopes;

  factory SourceBrowserAuthorizationOptions.parse(
    Map<String, dynamic> request,
  ) {
    Never invalid() => throw const SourceBrowserAuthorizationException(
      'login_invalid_browser_options',
    );
    final url = authorizationHttpsUri(request['url']);
    final manual = request['completion'] == 'manual';
    if (request['completion'] != null &&
        !const ['manual', 'callback'].contains(request['completion'])) {
      invalid();
    }
    final raw = request['callbacks'] ?? (manual ? const [] : null);
    final timeout = request['timeoutMs'] ?? 300000;
    if (url == null ||
        raw is! List ||
        (!manual && raw.isEmpty) ||
        raw.length > 16 ||
        timeout is! int ||
        timeout < 30000 ||
        timeout > 600000) {
      invalid();
    }
    final callbacks = <SourceAuthorizationCallback>[];
    final scopes = <SourceAuthorizationCookieScope>[];
    final rawScopes = request['cookieScopes'] ?? const [];
    if (rawScopes is! List || rawScopes.length > 16) invalid();
    for (final scope in rawScopes) {
      if (scope is! Map) invalid();
      final scopeUrl = authorizationHttpsUri(scope['url']);
      final names = scope['names'];
      if (scopeUrl == null ||
          names is! List ||
          names.isEmpty ||
          names.length > 64 ||
          names.any(
            (n) =>
                n is! String ||
                !RegExp(r'^[!#$%&\x27*+.^_`|~0-9a-zA-Z-]+$').hasMatch(n),
          )) {
        invalid();
      }
      scopes.add(
        SourceAuthorizationCookieScope(
          scopeUrl.toString(),
          List<String>.unmodifiable(names.cast<String>()),
        ),
      );
    }
    for (final item in raw) {
      if (item is! Map) invalid();
      final origin = authorizationHttpsUri(item['origin']);
      final path = item['path'];
      final keys = item['requiredQueryKeys'] ?? const <String>[];
      if (origin == null ||
          origin.hasQuery ||
          origin.hasFragment ||
          (origin.path.isNotEmpty && origin.path != '/') ||
          path is! String ||
          !path.startsWith('/') ||
          path.startsWith('//') ||
          path.contains(RegExp(r'[?#\\\s]')) ||
          keys is! List ||
          keys.length > 32 ||
          keys.any((k) => k is! String || k.isEmpty || k.length > 128)) {
        invalid();
      }
      // Check round trips so encoded separators and dot paths cannot widen a rule.
      if (Uri.parse('${origin.origin}$path').path != path) invalid();
      callbacks.add(
        SourceAuthorizationCallback(
          origin.origin,
          path,
          List<String>.unmodifiable(keys.cast<String>()),
        ),
      );
    }
    return SourceBrowserAuthorizationOptions(
      url: url,
      callbacks: List.unmodifiable(callbacks),
      timeout: Duration(milliseconds: timeout),
      title: request['title'],
      manual: manual,
      cookieScopes: List.unmodifiable(scopes),
    );
  }
}

class SourceAuthorizationCookieScope {
  const SourceAuthorizationCookieScope(this.url, this.names);
  final String url;
  final List<String> names;
  Map<String, Object> toJson() => {'url': url, 'names': names};
}

enum SourceAuthorizationState {
  preparing,
  browsing,
  completed,
  cancelled,
  timeout,
  failed,
}

/// One-shot result arbitration shared by all owned browser windows.
class SourceBrowserAuthorizationSession extends ChangeNotifier {
  SourceBrowserAuthorizationSession(this.options, this.cancellation) {
    cancellation.addListener(cancel);
    if (cancellation.isCancelled) {
      cancel();
    } else {
      _timer = Timer(
        options.timeout,
        () => _finish(SourceAuthorizationState.timeout, {'status': 'timeout'}),
      );
    }
  }
  final SourceBrowserAuthorizationOptions options;
  final SourceLoginCancellation cancellation;
  final String id = List.generate(
    16,
    (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  final _result = Completer<Map<String, Object>>();
  Timer? _timer;
  SourceAuthorizationState state = SourceAuthorizationState.preparing;
  String? origin;
  bool loading = true;
  bool completing = false;
  bool missingCookies = false;
  Future<List<Map<String, Object?>>> Function()? readCookies;
  bool get isActive =>
      state == SourceAuthorizationState.preparing ||
      state == SourceAuthorizationState.browsing;
  Future<Map<String, Object>> get result => _result.future;

  /// Returns true only when navigation may continue inside this session.
  bool navigate(String value, {required bool isMainFrame}) {
    if (!isActive) return false;
    final uri = authorizationHttpsUri(value);
    if (uri == null) return false;
    if (isMainFrame) {
      if (!options.manual &&
          options.callbacks.any((rule) => rule.matches(uri))) {
        unawaited(complete(value));
        return false;
      }
      origin = uri.origin;
      state = SourceAuthorizationState.browsing;
      notifyListeners();
    }
    return true;
  }

  Future<void> complete([String? callbackUrl]) async {
    if (!isActive || completing) return;
    completing = true;
    notifyListeners();
    try {
      final cookies = options.cookieScopes.isEmpty
          ? <Map<String, Object?>>[]
          : await readCookies!();
      if (!isActive) return;
      missingCookies = options.cookieScopes.any(
        (scope) => scope.names.any(
          (name) => !cookies.any(
            (cookie) =>
                cookie['scopeUrl'] == scope.url && cookie['name'] == name,
          ),
        ),
      );
      if (missingCookies) return;
      _finish(SourceAuthorizationState.completed, {
        'status': 'completed',
        'url': callbackUrl ?? options.url.toString(),
        if (cookies.isNotEmpty) '_cookies': cookies,
      });
    } catch (_) {
      fail('login_browser_cookie_unavailable');
    } finally {
      completing = false;
      if (isActive) notifyListeners();
    }
  }

  void setLoading(bool value) {
    if (!isActive || loading == value) return;
    loading = value;
    notifyListeners();
  }

  void fail(String code) {
    if (!isActive) return;
    state = SourceAuthorizationState.failed;
    _timer?.cancel();
    _result.completeError(SourceBrowserAuthorizationException(code));
    notifyListeners();
  }

  void cancel() {
    if (!isActive) return;
    state = SourceAuthorizationState.cancelled;
    _timer?.cancel();
    _result.completeError(const SourceLoginCancelled());
    notifyListeners();
  }

  void _finish(SourceAuthorizationState next, Map<String, Object> value) {
    if (!isActive) return;
    state = next;
    _timer?.cancel();
    _result.complete(value);
    notifyListeners();
  }

  @override
  void dispose() {
    cancellation.removeListener(cancel);
    cancel();
    _timer?.cancel();
    super.dispose();
  }
}
