import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:enough_convert/gbk.dart';
import 'package:pointycastle/api.dart'
    show BlockCipher, CipherParameters, KeyParameter, ParametersWithIV;
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/cbc.dart';
import 'package:pointycastle/block/modes/cfb.dart';
import 'package:pointycastle/block/modes/ecb.dart';
import 'package:pointycastle/block/modes/ofb.dart';

import '../common/source_json_coerce.dart';
import 'source_html_bridge.dart';
import 'source_rsa_key.dart';

/// Pure host capabilities owned by one script worker.
class SourceLocalScriptBridge {
  final SourceHtmlBridge html = SourceHtmlBridge();
  static const methods = {'html', 'convert'};
  static final _secureRandom = Random.secure();

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
        return _processAes(ECBBlockCipher(AESEngine()), encode, request);
      case 'aes-cbc':
        return _processAes(
          CBCBlockCipher(AESEngine()),
          encode,
          request,
          withIv: true,
        );
      case 'aes-cfb':
        return _processAes(
          CFBBlockCipher(AESEngine(), _aesSegmentSize(request)),
          encode,
          request,
          withIv: true,
        );
      case 'aes-ofb':
        return _processAes(
          OFBBlockCipher(AESEngine(), _aesSegmentSize(request)),
          encode,
          request,
          withIv: true,
        );
      case 'gbk':
        return encode
            ? Uint8List.fromList(
                const GbkCodec().encode((value ?? '').toString()),
              )
            : const GbkCodec().decode(jsToBytes(value));
      case 'rsa':
        return decryptRsaForPlugin(
          value,
          request['key'],
          padding: request['padding']?.toString(),
        );
      case 'random':
        final length = request['length'];
        if (length is! num ||
            length != length.toInt() ||
            length < 1 ||
            length > 1024) {
          throw const FormatException('plugin_invalid_random_length');
        }
        return Uint8List.fromList([
          for (var i = 0; i < length.toInt(); i++) _secureRandom.nextInt(256),
        ]);
      default:
        // 未知类型必须显式失败，避免插件把原样返回的输入误当作转换结果。
        throw UnsupportedError(
          'plugin_unsupported_convert_type: ${request['type']}',
        );
    }
  }

  /// 不做自动填充：输入须按分组对齐，填充由插件自行处理（与既有 ECB 行为一致）。
  Uint8List _processAes(
    BlockCipher cipher,
    bool encode,
    Map<String, dynamic> request, {
    bool withIv = false,
  }) {
    final key = jsToBytes(request['key']);
    if (!const {16, 24, 32}.contains(key.length)) {
      throw const FormatException('plugin_invalid_cipher_key');
    }
    CipherParameters parameters = KeyParameter(key);
    if (withIv) {
      final iv = jsToBytes(request['iv']);
      if (iv.length != 16) {
        throw const FormatException('plugin_invalid_cipher_iv');
      }
      parameters = ParametersWithIV(parameters, iv);
    }
    cipher.init(encode, parameters);
    final bytes = jsToBytes(request['value']);
    if (bytes.length % cipher.blockSize != 0) {
      throw const FormatException('plugin_invalid_cipher_input');
    }
    final result = Uint8List(bytes.length);
    for (var offset = 0; offset < bytes.length;) {
      offset += cipher.processBlock(bytes, offset, result, offset);
    }
    return result;
  }

  /// CFB/OFB 的分段字节数，省略时为完整的 16 字节分组。
  int _aesSegmentSize(Map<String, dynamic> request) {
    final size = request['blockSize'] ?? 16;
    if (size is! num || size != size.toInt() || size < 1 || size > 16) {
      throw const FormatException('plugin_invalid_cipher_block_size');
    }
    return size.toInt();
  }
}
