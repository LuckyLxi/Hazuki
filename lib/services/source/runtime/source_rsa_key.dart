import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/api.dart'
    show AsymmetricBlockCipher, PrivateKeyParameter;
import 'package:pointycastle/asn1.dart';
import 'package:pointycastle/asymmetric/api.dart' show RSAPrivateKey;
import 'package:pointycastle/asymmetric/oaep.dart';
import 'package:pointycastle/asymmetric/pkcs1.dart';
import 'package:pointycastle/asymmetric/rsa.dart';

import '../common/source_json_coerce.dart';

/// 用插件提供的私钥解密 RSA 密文；密文超过一个模长时按块依次解密后拼接。
Uint8List decryptRsaForPlugin(dynamic value, dynamic key, {String? padding}) {
  final cipher = switch (padding ?? 'pkcs1') {
    'pkcs1' => PKCS1Encoding(RSAEngine()),
    'oaep' => OAEPEncoding(RSAEngine()),
    _ => throw const FormatException('plugin_invalid_rsa_padding'),
  };
  cipher.init(
    false,
    PrivateKeyParameter<RSAPrivateKey>(parseRsaPrivateKey(key)),
  );
  return _processRsaBlocks(cipher, jsToBytes(value));
}

/// 解析 PEM（PKCS#1 / PKCS#8）字符串或 DER 字节形式的 RSA 私钥。
RSAPrivateKey parseRsaPrivateKey(dynamic key) {
  try {
    final der = key is String ? _pemToDer(key) : jsToBytes(key);
    var sequence = ASN1Parser(der).nextObject() as ASN1Sequence;
    var elements = sequence.elements!;
    // PKCS#8 外层为 version、算法标识和包裹 PKCS#1 私钥的 OCTET STRING。
    if (elements.length == 3 && elements[2] is ASN1OctetString) {
      final inner = (elements[2] as ASN1OctetString).octets!;
      sequence = ASN1Parser(inner).nextObject() as ASN1Sequence;
      elements = sequence.elements!;
    }
    BigInt integerAt(int index) => (elements[index] as ASN1Integer).integer!;
    return RSAPrivateKey(
      integerAt(1),
      integerAt(3),
      integerAt(4),
      integerAt(5),
    );
  } catch (_) {
    throw const FormatException('plugin_invalid_rsa_key');
  }
}

Uint8List _pemToDer(String pem) {
  final body = pem
      .split(RegExp(r'\r?\n'))
      .where((line) => !line.startsWith('-----'))
      .join()
      .replaceAll(RegExp(r'\s'), '');
  if (body.isEmpty) throw const FormatException('plugin_invalid_rsa_key');
  return base64Decode(body);
}

Uint8List _processRsaBlocks(AsymmetricBlockCipher cipher, Uint8List input) {
  final blockSize = cipher.inputBlockSize;
  if (input.isEmpty || input.length % blockSize != 0) {
    throw const FormatException('plugin_invalid_cipher_input');
  }
  final output = BytesBuilder(copy: false);
  for (var offset = 0; offset < input.length; offset += blockSize) {
    output.add(
      cipher.process(Uint8List.sublistView(input, offset, offset + blockSize)),
    );
  }
  return output.takeBytes();
}
