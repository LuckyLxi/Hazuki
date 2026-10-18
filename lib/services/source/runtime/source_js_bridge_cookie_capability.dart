import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/api.dart' show KeyParameter;
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/ecb.dart';

import '../common/source_json_coerce.dart';
import '../account/source_browser_authorization.dart';
import '../account/source_external_authorization.dart';
import 'source_runtime_facade.dart';
import 'source_runtime_handle.dart';
import 'source_cookie_store.dart';
import 'source_html_bridge.dart';
import '../plugins/source_plugin_models.dart';
import '../plugins/source_plugin_localization.dart';

/// Handles the JavaScript host bridge and its cookie operations.
class SourceJsBridgeCookieCapability {
  SourceJsBridgeCookieCapability({
    required SourceRuntimeHandle Function() activeHandle,
  }) : _activeHandle = activeHandle;

  final SourceRuntimeHandle Function() _activeHandle;

  Future<dynamic> handleCookieOperationForHandle(
    SourceRuntimeHandleView handle,
    Map<String, dynamic> request,
  ) => handle.cookieStore.handleOperation(request);

  String? buildCookieHeader(String url) =>
      _activeHandle().cookieStore.buildHeader(url);

  String? buildCookieHeaderForHandle(
    SourceRuntimeHandleView handle,
    String url,
  ) => handle.cookieStore.buildHeader(url);

  Future<void> saveCookiesFromHeadersForHandle(
    SourceRuntimeHandleView handle,
    String url,
    Map<String, List<String>> headers,
  ) => handle.cookieStore.saveFromHeaders(url, headers);

  dynamic handleJsMessageForHandle(
    SourceRuntimeHandle handle,
    dynamic message, {
    SourceHtmlBridge? htmlBridge,
  }) {
    if (message is! Map) return null;
    final map = Map<String, dynamic>.from(message);
    final method = map['method']?.toString();
    dynamic result;
    if (handle.isDisposed) throw StateError('plugin_runtime_disposed');
    handle.loginCancellation?.check();
    switch (method) {
      case 'login_external_prepare':
      case 'login_external_close':
        final cancellation = handle.loginCancellation;
        if (cancellation == null || handle.loginPresenter == null) {
          throw StateError('login_interaction_required');
        }
        final broker = SourceExternalAuthorizationBroker.instance;
        result = method == 'login_external_prepare'
            ? broker.prepare(
                Map<String, dynamic>.from(map['request'] as Map),
                cancellation,
              )
            : broker.close(map['id']?.toString() ?? '', cancellation);
        break;
      case 'login_interaction':
        final cancellation = handle.loginCancellation;
        final present = handle.loginPresenter;
        if (cancellation == null || present == null) {
          throw StateError('login_interaction_required');
        }
        cancellation.check();
        final request = Map<String, dynamic>.from(map['request'] as Map);
        if (request['type'] == 'externalAuthorization') {
          SourceExternalAuthorizationBroker.instance.require(
            request['id']?.toString() ?? '',
            cancellation,
          );
          request['sourceName'] =
              handle.runtime.sourceMeta?.name ?? handle.sourceKey;
        }
        if (request['type'] == 'browserAuthorization') {
          SourceBrowserAuthorizationOptions.parse(request);
          request['sourceName'] =
              handle.runtime.sourceMeta?.name ?? handle.sourceKey;
        }
        final count = request['pointCount'];
        if (count != null && (count is! int || count < 1 || count > 32)) {
          throw const FormatException('login_invalid_point_count');
        }
        result = present(request, cancellation).then((value) async {
          cancellation.check();
          if (request['type'] != 'browserAuthorization' || value is! Map) {
            return value;
          }
          final response = Map<String, dynamic>.from(value);
          final cookies = response.remove('_cookies');
          final options = SourceBrowserAuthorizationOptions.parse(request);
          if (response['status'] == 'completed' &&
              options.cookieScopes.isNotEmpty) {
            if (cookies is! List) {
              throw StateError('login_browser_cookie_missing');
            }
            for (final scope in options.cookieScopes) {
              final selected = cookies
                  .whereType<Map>()
                  .where(
                    (c) =>
                        c['scopeUrl'] == scope.url &&
                        scope.names.contains(c['name']),
                  )
                  .map(
                    (c) => SourceCookie.fromMap(Map<String, dynamic>.from(c)),
                  )
                  .where(
                    (c) =>
                        c.matches(Uri.parse(scope.url)) &&
                        !c.isExpired(DateTime.now().millisecondsSinceEpoch),
                  )
                  .toList();
              if (scope.names.any((n) => !selected.any((c) => c.name == n))) {
                throw StateError('login_browser_cookie_missing');
              }
              await handle.cookieStore.set(scope.url, selected);
              cancellation.check();
            }
          }
          return response;
        });
        break;
      case 'html':
        result = (htmlBridge ?? handle.htmlBridge).handleOperation(map);
        break;
      case 'secret_get':
      case 'secret_set':
      case 'secret_delete':
        final key = map['secret_key']?.toString() ?? '';
        if (!RegExp(r'^[a-zA-Z0-9_.-]{1,64}$').hasMatch(key)) {
          throw const SourcePluginException('plugin_invalid_secret_key');
        }
        final scoped = 'hazuki_plugin_secret_v1:${handle.sourceKey}:$key';
        result = method == 'secret_get'
            ? handle.secureStorage.read(scoped)
            : method == 'secret_delete'
            ? handle.secureStorage.delete(scoped)
            : handle.secureStorage.write(scoped, map['value'].toString());
        break;
      case 'save_setting':
        result = handle.facade.saveSourceSetting(
          _requireScopedSourceKey(handle, map),
          map['setting_key']?.toString() ?? '',
          map['value'],
        );
        break;
      case 'http':
        result = handle.facade.httpGateway.sendJsHttpRequest(map);
        break;
      case 'cookie':
        result = handleCookieOperationForHandle(handle, map);
        break;
      case 'load_data':
        result = handle.facade.loadSourceData(
          _requireScopedSourceKey(handle, map),
          map['data_key']?.toString() ?? '',
        );
        break;
      case 'save_data':
        result = handle.facade.saveSourceData(
          _requireScopedSourceKey(handle, map),
          map['data_key']?.toString() ?? '',
          map['data'],
        );
        break;
      case 'delete_data':
        result = handle.facade.deleteSourceData(
          _requireScopedSourceKey(handle, map),
          map['data_key']?.toString() ?? '',
        );
        break;
      case 'load_setting':
        final settingKey = map['setting_key']?.toString() ?? '';
        result = handle.session.loadSourceSetting(
          sourceKey: _requireScopedSourceKey(handle, map),
          settingKey: settingKey,
          sourceMeta: handle.runtime.sourceMeta,
          settingsDefaults: map.containsKey('default_value')
              ? {settingKey: map['default_value']}
              : null,
        );
        break;
      case 'isLogged':
        _requireScopedSourceKey(handle, map);
        result = handle.facade.isLogged;
        break;
      case 'delay':
        final ms = map['time'] is num ? (map['time'] as num).toInt() : 0;
        result = Future<void>.delayed(Duration(milliseconds: ms));
        break;
      case 'random':
        result = _random(map);
        break;
      case 'uuid':
        result = _uuid();
        break;
      case 'convert':
        result = _convert(map);
        break;
      case 'getLocale':
        result = sourcePluginLocaleTag(handle.session.prefs);
        break;
      case 'getPlatform':
        final os = Platform.operatingSystem;
        result = (os == 'android' || os == 'ios') ? os : 'android';
        break;
      case 'log':
        // Foreground login may hold a complete authorization callback. Never
        // forward plugin console data from this transient runtime to diagnostics.
        if (handle.loginCancellation != null) break;
        handle.facade.addApplicationLog(
          level: map['level']?.toString() ?? 'info',
          title: map['title']?.toString() ?? 'Application',
          content: map['content'],
          source: 'js_console',
        );
        break;
      default:
        throw UnsupportedError('Unsupported JS bridge method: $method');
    }
    return result;
  }

  void configureDioCookieBridge([SourceRuntimeHandle? handle]) =>
      (handle ?? _activeHandle()).facade.httpGateway.configureCookieBridge();

  String _requireScopedSourceKey(
    SourceRuntimeHandle handle,
    Map<String, dynamic> request,
  ) {
    final requested = request['key']?.toString().trim() ?? '';
    if (requested != handle.sourceKey) {
      throw StateError(
        'source_bridge_scope_violation:${handle.sourceKey}:$requested',
      );
    }
    return handle.sourceKey;
  }

  dynamic _random(Map<String, dynamic> request) {
    final min = request['min'] is num ? request['min'] as num : 0;
    final max = request['max'] is num ? request['max'] as num : 1;
    if (request['type']?.toString() == 'double') {
      return min + (max - min) * DateTime.now().microsecond / 1000000;
    }
    final range = (max - min).toInt();
    return range <= 0
        ? min.toInt()
        : min.toInt() + DateTime.now().microsecond % range;
  }

  String _uuid() {
    final bytes = List<int>.generate(
      16,
      (_) => math.Random.secure().nextInt(256),
    );
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  dynamic _convert(Map<String, dynamic> request) {
    final value = request['value'];
    final encode = request['isEncode'] == true;
    switch (request['type']?.toString()) {
      case 'utf8':
        return encode
            ? utf8.encode((value ?? '').toString())
            : utf8.decode(jsToBytes(value));
      case 'base64':
        return encode
            ? base64Encode(jsToBytes(value))
            : base64Decode((value ?? '').toString());
      case 'md5':
        return Uint8List.fromList(md5.convert(jsToBytes(value)).bytes);
      case 'sha1':
        return Uint8List.fromList(sha1.convert(jsToBytes(value)).bytes);
      case 'sha256':
        return Uint8List.fromList(sha256.convert(jsToBytes(value)).bytes);
      case 'sha512':
        return Uint8List.fromList(sha512.convert(jsToBytes(value)).bytes);
      case 'hmac':
        final algorithm = switch (request['hash']?.toString()) {
          'sha1' => sha1,
          'sha256' => sha256,
          'sha512' => sha512,
          _ => md5,
        };
        final digest = Hmac(
          algorithm,
          jsToBytes(request['key']),
        ).convert(jsToBytes(value));
        return request['isString'] == true
            ? digest.toString()
            : Uint8List.fromList(digest.bytes);
      case 'aes-ecb':
        final bytes = jsToBytes(value);
        final cipher = ECBBlockCipher(AESEngine())
          ..init(encode, KeyParameter(jsToBytes(request['key'])));
        final result = Uint8List(bytes.length);
        for (var offset = 0; offset < bytes.length;) {
          offset += cipher.processBlock(bytes, offset, result, offset);
        }
        return result;
      case 'gbk':
      case 'aes-cbc':
      case 'aes-cfb':
      case 'aes-ofb':
      case 'rsa':
        throw UnsupportedError('Unsupported conversion: ${request['type']}');
      default:
        return value;
    }
  }
}
