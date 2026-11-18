import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/runtime/source_local_script_bridge.dart';
import 'package:pointycastle/asn1.dart';
import 'package:pointycastle/export.dart';

Uint8List _hex(String value) => Uint8List.fromList([
  for (var i = 0; i < value.length; i += 2)
    int.parse(value.substring(i, i + 2), radix: 16),
]);

String _toHex(dynamic bytes) =>
    (bytes as List<int>).map((b) => b.toRadixString(16).padLeft(2, '0')).join();

Matcher _throwsCode(String code) => throwsA(
  isA<FormatException>().having((error) => error.message, 'message', code),
);

// NIST SP 800-38A AES-128 向量。
final _key = _hex('2b7e151628aed2a6abf7158809cf4f3c');
final _iv = _hex('000102030405060708090a0b0c0d0e0f');
const _plain =
    '6bc1bee22e409f96e93d7e117393172aae2d8a571e03ac9c9eb76fac45af8e51';

AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> _rsaKeyPair() {
  final random = FortunaRandom()..seed(KeyParameter(Uint8List(32)));
  final generator = RSAKeyGenerator()
    ..init(
      ParametersWithRandom(
        RSAKeyGeneratorParameters(BigInt.from(65537), 1024, 64),
        random,
      ),
    );
  return generator.generateKeyPair();
}

Uint8List _pkcs1Der(RSAPrivateKey key) {
  final p = key.p!;
  final q = key.q!;
  final d = key.privateExponent!;
  return (ASN1Sequence()
        ..add(ASN1Integer(BigInt.zero))
        ..add(ASN1Integer(key.modulus))
        ..add(ASN1Integer(key.publicExponent))
        ..add(ASN1Integer(d))
        ..add(ASN1Integer(p))
        ..add(ASN1Integer(q))
        ..add(ASN1Integer(d % (p - BigInt.one)))
        ..add(ASN1Integer(d % (q - BigInt.one)))
        ..add(ASN1Integer(q.modInverse(p))))
      .encode();
}

Uint8List _pkcs8Der(RSAPrivateKey key) {
  final algorithm = ASN1Sequence()
    ..add(ASN1ObjectIdentifier.fromIdentifierString('1.2.840.113549.1.1.1'))
    ..add(ASN1Null());
  return (ASN1Sequence()
        ..add(ASN1Integer(BigInt.zero))
        ..add(algorithm)
        ..add(ASN1OctetString(octets: _pkcs1Der(key))))
      .encode();
}

String _pem(String label, Uint8List der) {
  final body = base64Encode(der);
  final lines = [
    for (var i = 0; i < body.length; i += 64)
      body.substring(i, i + 64 > body.length ? body.length : i + 64),
  ];
  return '-----BEGIN $label-----\n${lines.join('\n')}\n-----END $label-----\n';
}

void main() {
  final bridge = SourceLocalScriptBridge();
  dynamic convert(Map<String, dynamic> request) =>
      bridge.convert({'key': _key, 'iv': _iv, ...request});

  group('aes', () {
    final vectors = {
      'aes-ecb': (
        null,
        '3ad77bb40d7a3660a89ecaf32466ef97f5d3d58503b9699de785895a96fdbaaf',
      ),
      'aes-cbc': (
        null,
        '7649abac8119b246cee98e9b12e9197d5086cb9b507219ee95db113a917678b2',
      ),
      'aes-cfb': (
        16,
        '3b3fd92eb72dad20333449f8e83cfb4ac8a64537a0b3a93fcde3cdad9f1ce58b',
      ),
      'aes-ofb': (
        16,
        '3b3fd92eb72dad20333449f8e83cfb4a7789508d16918f03f53c52dac54ed825',
      ),
    };
    for (final MapEntry(key: type, value: (blockSize, cipher))
        in vectors.entries) {
      test('$type matches NIST vectors in both directions', () {
        final encrypted = convert({
          'type': type,
          'value': _hex(_plain),
          'blockSize': ?blockSize,
          'isEncode': true,
        });
        expect(_toHex(encrypted), cipher);
        final decrypted = convert({
          'type': type,
          'value': _hex(cipher),
          'blockSize': ?blockSize,
          'isEncode': false,
        });
        expect(_toHex(decrypted), _plain);
      });
    }

    test('cfb-8 accepts unaligned input', () {
      const plain = '6bc1bee22e409f96e93d7e117393172aae2d';
      const cipher = '3b79424c9c0dd436bace9e0ed4586a4f32b9';
      final encrypted = convert({
        'type': 'aes-cfb',
        'value': _hex(plain),
        'blockSize': 1,
        'isEncode': true,
      });
      expect(_toHex(encrypted), cipher);
      final decrypted = convert({
        'type': 'aes-cfb',
        'value': _hex(cipher),
        'blockSize': 1,
        'isEncode': false,
      });
      expect(_toHex(decrypted), plain);
    });

    test('rejects invalid keys, ivs, block sizes and unaligned input', () {
      expect(
        () => convert({'type': 'aes-ecb', 'key': _hex('00'), 'value': _iv}),
        _throwsCode('plugin_invalid_cipher_key'),
      );
      expect(
        () => convert({'type': 'aes-cbc', 'iv': null, 'value': _iv}),
        _throwsCode('plugin_invalid_cipher_iv'),
      );
      expect(
        () => convert({'type': 'aes-cfb', 'blockSize': 17, 'value': _iv}),
        _throwsCode('plugin_invalid_cipher_block_size'),
      );
      for (final type in ['aes-ecb', 'aes-cbc']) {
        expect(
          () => convert({'type': type, 'value': _hex('0011')}),
          _throwsCode('plugin_invalid_cipher_input'),
        );
      }
    });
  });

  group('rsa', () {
    final pair = _rsaKeyPair();
    final message = utf8.encode('hazuki rsa payload');

    Uint8List encrypt(AsymmetricBlockCipher cipher) {
      cipher.init(true, PublicKeyParameter<RSAPublicKey>(pair.publicKey));
      return cipher.process(Uint8List.fromList(message));
    }

    test('decrypts pkcs1 and oaep with pkcs1, pkcs8 and der keys', () {
      final keys = <dynamic>[
        _pem('RSA PRIVATE KEY', _pkcs1Der(pair.privateKey)),
        _pem('PRIVATE KEY', _pkcs8Der(pair.privateKey)),
        _pkcs1Der(pair.privateKey),
      ];
      for (final key in keys) {
        expect(
          bridge.convert({
            'type': 'rsa',
            'key': key,
            'value': encrypt(PKCS1Encoding(RSAEngine())),
          }),
          message,
        );
        expect(
          bridge.convert({
            'type': 'rsa',
            'key': key,
            'padding': 'oaep',
            'value': encrypt(OAEPEncoding(RSAEngine())),
          }),
          message,
        );
      }
    });

    test('rejects malformed keys and unknown padding', () {
      final value = encrypt(PKCS1Encoding(RSAEngine()));
      expect(
        () =>
            bridge.convert({'type': 'rsa', 'key': 'not a key', 'value': value}),
        _throwsCode('plugin_invalid_rsa_key'),
      );
      expect(
        () => bridge.convert({
          'type': 'rsa',
          'key': _pkcs1Der(pair.privateKey),
          'padding': 'none',
          'value': value,
        }),
        _throwsCode('plugin_invalid_rsa_padding'),
      );
    });
  });

  test('gbk round-trips Chinese text', () {
    final encoded = bridge.convert({
      'type': 'gbk',
      'value': '漫画',
      'isEncode': true,
    });
    expect(_toHex(encoded), 'c2febbad');
    expect(
      bridge.convert({'type': 'gbk', 'value': encoded, 'isEncode': false}),
      '漫画',
    );
  });

  test('random returns secure bytes of the requested length', () {
    final first = bridge.convert({'type': 'random', 'length': 32});
    final second = bridge.convert({'type': 'random', 'length': 32});
    expect(first, isA<Uint8List>().having((b) => b.length, 'length', 32));
    expect(first, isNot(second));
    for (final length in [0, 1025, 1.5, '16', null]) {
      expect(
        () => bridge.convert({'type': 'random', 'length': length}),
        _throwsCode('plugin_invalid_random_length'),
      );
    }
  });

  test('unknown conversion types fail instead of echoing input', () {
    expect(
      () => bridge.convert({'type': 'rot13', 'value': 'abc'}),
      throwsA(isA<UnsupportedError>()),
    );
  });
}
