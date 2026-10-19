import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/api.dart' show KeyParameter;
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/ecb.dart';

import '../common/source_json_coerce.dart';
import 'source_html_bridge.dart';

/// Pure host capabilities owned by one script worker.
class SourceLocalScriptBridge {
  final SourceHtmlBridge html = SourceHtmlBridge();
  static const methods = {'html', 'convert', 'random', 'uuid', 'getPlatform'};

  dynamic handle(Map<String, dynamic> request) => switch (request['method']) {
    'html' => html.handleOperation(request),
    'convert' => convert(request),
    'random' => random(request),
    'uuid' => uuid(),
    'getPlatform' => switch (Platform.operatingSystem) {
      'ios' => 'ios',
      _ => 'android',
    },
    _ => throw UnsupportedError('Unsupported local bridge method'),
  };
  dynamic random(Map<String, dynamic> request) {
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

  String uuid() {
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

  dynamic convert(Map<String, dynamic> request) {
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
