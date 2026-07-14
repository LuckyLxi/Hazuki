import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/api.dart' show KeyParameter;
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/ecb.dart';

import '../common/source_json_coerce.dart';
import 'source_runtime_facade.dart';
import 'source_runtime_handle.dart';

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
    dynamic message,
  ) {
    if (message is! Map) return null;
    final map = Map<String, dynamic>.from(message);
    final method = map['method']?.toString();
    dynamic result;
    switch (method) {
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
        result = handle.facade.loadSourceSetting(
          _requireScopedSourceKey(handle, map),
          map['setting_key']?.toString() ?? '',
        );
        break;
      case 'isLogged':
        _requireScopedSourceKey(handle, map);
        result = handle.facade.loadAccountDataSync() != null;
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
        result = 'zh_CN';
        break;
      case 'getPlatform':
        final os = Platform.operatingSystem;
        result = (os == 'android' || os == 'ios') ? os : 'android';
        break;
      case 'log':
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
    return result is Future
        ? result.whenComplete(
            () => handle.runtime.engine?.port.sendPort.send(null),
          )
        : result;
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
