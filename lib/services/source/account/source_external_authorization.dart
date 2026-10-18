import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';
import 'source_login_interaction.dart';

const _forbiddenAuthorizationSchemes = {
  'file',
  'javascript',
  'data',
  'vbscript',
  'shell',
  'powershell',
  'cmd',
  'intent',
  'about',
  'blob',
  'ms-msdt',
  'search-ms',
  'ms-settings',
};

class SourceExternalAuthorizationOptions {
  SourceExternalAuthorizationOptions(Map<String, dynamic> raw) {
    final schemes = raw['allowedSchemes'];
    final milliseconds = raw['timeoutMs'] ?? 300000;
    final package = raw['androidPackage'];
    if (schemes is! List ||
        schemes.isEmpty ||
        schemes.length > 16 ||
        schemes.any(
          (s) =>
              s is! String ||
              !RegExp(r'^[a-z][a-z0-9+.-]{1,63}$').hasMatch(s) ||
              _forbiddenAuthorizationSchemes.contains(s),
        ) ||
        milliseconds is! int ||
        milliseconds < 30000 ||
        milliseconds > 600000 ||
        (package != null &&
            (package is! String ||
                !RegExp(
                  r'^[a-zA-Z][\w]*(\.[a-zA-Z][\w]*)+$',
                ).hasMatch(package)))) {
      throw StateError('login_invalid_external_options');
    }
    allowedSchemes = List<String>.unmodifiable(schemes.cast<String>());
    timeout = Duration(milliseconds: milliseconds);
    androidPackage = package as String?;
  }
  late final List<String> allowedSchemes;
  late final Duration timeout;
  late final String? androidPackage;
  bool allows(String url) {
    if (url.length > 32768 || url.contains(RegExp(r'[\s\\]'))) return false;
    final uri = Uri.tryParse(url);
    return uri != null &&
        allowedSchemes.contains(uri.scheme) &&
        uri.userInfo.isEmpty;
  }
}

/// Owns only foreground, current-process sessions. URLs never enter diagnostics.
class SourceExternalAuthorizationSession {
  SourceExternalAuthorizationSession(
    this.options,
    this.cancellation, {
    MethodChannel? channel,
  }) : _channel =
           channel ?? const MethodChannel('hazuki/external_authorization') {
    cancellation.addListener(cancel);
    _timer = Timer(options.timeout, () => _finish({'status': 'timeout'}));
  }
  final SourceExternalAuthorizationOptions options;
  final SourceLoginCancellation cancellation;
  final MethodChannel _channel;
  final id = List.generate(
    16,
    (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  final _result = Completer<Map<String, Object>>();
  Timer? _timer;
  Uri? callback;
  bool _launched = false;
  bool get active => !_result.isCompleted;
  Future<Map<String, Object>> get result => _result.future;

  Future<String> prepare() async {
    cancellation.check();
    final value = await _channel.invokeMethod<String>('prepare', {'id': id});
    cancellation.check();
    final uri = Uri.tryParse(value ?? '');
    if (uri == null ||
        !uri.scheme.startsWith('hazuki-auth') ||
        uri.host != 'authorize' ||
        uri.path != '/$id' ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw StateError('login_external_unavailable');
    }
    callback = uri;
    return uri.toString();
  }

  Future<Map<String, Object>> launch(String url) async {
    cancellation.check();
    if (!active) return result;
    if (_launched || callback == null || !options.allows(url)) {
      throw StateError('login_invalid_external_url');
    }
    _launched = true;
    try {
      if (await _channel.invokeMethod<bool>('launch', {
            'id': id,
            'url': url,
            'allowedSchemes': options.allowedSchemes,
            'androidPackage': options.androidPackage,
          }) !=
          true) {
        throw StateError('login_external_app_unavailable');
      }
      return await result;
    } on SourceLoginCancelled {
      rethrow;
    } catch (_) {
      if (cancellation.isCancelled) throw const SourceLoginCancelled();
      throw StateError('login_external_app_unavailable');
    }
  }

  bool accept(String url) {
    if (!active || !_launched || callback == null || url.length > 32768) {
      return false;
    }
    final uri = Uri.tryParse(url);
    final expected = callback!;
    if (uri == null ||
        uri.scheme != expected.scheme ||
        uri.authority != expected.authority ||
        uri.path != expected.path ||
        uri.userInfo.isNotEmpty) {
      return false;
    }
    _finish({'status': 'completed', 'url': url});
    return true;
  }

  void _finish(Map<String, Object> result) {
    if (!active) return;
    _timer?.cancel();
    _result.complete(result);
  }

  void cancel() {
    if (!active) return;
    _timer?.cancel();
    _result.completeError(const SourceLoginCancelled());
  }

  Future<void> dispose() async {
    cancellation.removeListener(cancel);
    cancel();
    try {
      await _channel.invokeMethod<void>('close', {'id': id});
    } catch (_) {
      /* Process-local native cleanup is retried at shutdown. */
    }
  }
}

class SourceExternalAuthorizationBroker {
  SourceExternalAuthorizationBroker._() {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'callback' || call.arguments is! String) return;
      for (final session in _sessions.values.toList()) {
        if (session.accept(call.arguments as String)) break;
      }
    });
  }
  static final instance = SourceExternalAuthorizationBroker._();
  static const _channel = MethodChannel('hazuki/external_authorization');
  final _sessions = <String, SourceExternalAuthorizationSession>{};
  final _cancelListeners = <String, void Function()>{};
  Future<Map<String, Object>> prepare(
    Map<String, dynamic> request,
    SourceLoginCancellation cancellation,
  ) async {
    final session = SourceExternalAuthorizationSession(
      SourceExternalAuthorizationOptions(request),
      cancellation,
    );
    // Catch cancellation/timeout while the plugin is still constructing its URL.
    unawaited(session.result.then((_) {}, onError: (Object _) {}));
    _sessions[session.id] = session;
    void cancelled() {
      unawaited(close(session.id, cancellation));
    }

    cancellation.addListener(cancelled);
    _cancelListeners[session.id] = cancelled;
    unawaited(
      session.result.then((_) async {
        try {
          await _channel.invokeMethod<void>('close', {'id': session.id});
        } catch (_) {}
      }, onError: (Object _) {}),
    );
    try {
      final callbackUrl = await session.prepare();
      return {'id': session.id, 'callbackUrl': callbackUrl};
    } catch (_) {
      await close(session.id, cancellation);
      rethrow;
    }
  }

  SourceExternalAuthorizationSession require(
    String id,
    SourceLoginCancellation cancellation,
  ) {
    final session = _sessions[id];
    if (session == null || !identical(session.cancellation, cancellation)) {
      throw StateError('login_external_session_missing');
    }
    return session;
  }

  Future<void> close(String id, SourceLoginCancellation cancellation) async {
    final session = _sessions[id];
    if (session == null || !identical(session.cancellation, cancellation)) {
      return;
    }
    _sessions.remove(id);
    final listener = _cancelListeners.remove(id);
    if (listener != null) cancellation.removeListener(listener);
    await session.dispose();
  }
}
