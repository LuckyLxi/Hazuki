import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/account/picacg_login_profile_parser.dart';
import 'package:hazuki/services/source/account/picacg_profile_script_factory.dart';

void main() {
  const parser = PicacgLoginProfileParser();

  test('extracts login tokens from parsed and raw auth responses', () {
    expect(
      parser.extractLoginToken({
        'authResponses': [
          {
            'parsedBody': {
              'data': {'token': 'parsed-token'},
            },
          },
        ],
      }),
      'parsed-token',
    );
    expect(
      parser.extractLoginToken({
        'authResponses': [
          {'body': '{"data":{"token":"raw-token"}}'},
        ],
      }),
      'raw-token',
    );
    expect(parser.extractLoginToken(const {'authResponses': []}), isNull);
  });

  test('decodes valid JWT payloads and rejects malformed tokens', () {
    final payload = base64Url.encode(
      utf8.encode(jsonEncode({'name': 'Picacg User', 'level': 3})),
    );

    expect(parser.decodeJwtPayload('header.$payload.signature'), {
      'name': 'Picacg User',
      'level': 3,
    });
    expect(parser.decodeJwtPayload('malformed'), isNull);
  });

  test('parses nested profile names and normalized avatar urls', () {
    final profile = parser.parseProfileResult(
      sourceKey: 'picacg',
      result: {
        'parsedBody': {
          'data': {
            'user': {
              'name': 'Profile Name',
              'avatar': {
                'fileServer': 'https://storage.example',
                'path': 'avatars/user.jpg',
              },
            },
          },
        },
      },
    );

    expect(profile?.displayName, 'Profile Name');
    expect(
      profile?.avatarUrl,
      'https://storage.example/static/avatars/user.jpg',
    );
  });

  test(
    'profile script safely encodes tokens and tries both signature paths',
    () {
      const factory = PicacgProfileScriptFactory();

      final script = factory.build('token"with\ncontrol');

      expect(script, contains(r'token\"with\ncontrol'));
      expect(script, contains('requestProfile(path)'));
      expect(script, contains('requestProfile(unsignedPath)'));
      expect(script, contains('/users/profile'));
    },
  );
}
