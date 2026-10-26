import 'dart:convert';
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
  static const methods = {'html', 'convert'};

  dynamic handle(Map<String, dynamic> request) => switch (request['method']) {
    'html' => html.handleOperation(request),
    'convert' => convert(request),
    _ => throw UnsupportedError('Unsupported local bridge method'),
  };

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
