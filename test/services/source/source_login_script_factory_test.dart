import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/account/source_login_script_factory.dart';

void main() {
  const factory = SourceLoginScriptFactory();

  test('builds a safely encoded generic source login call', () {
    final script = factory.build(
      sourceKey: 'custom',
      account: 'user"name',
      password: 'line\nbreak',
    );

    expect(script.name, 'source_login.js');
    expect(script.code, contains(r'user\"name'));
    expect(script.code, contains(r'line\nbreak'));
    expect(script.code, startsWith('this.__hazuki_source.account.login('));
  });

  test('builds the CopyManga token-preserving login workflow', () {
    final script = factory.build(
      sourceKey: 'copy_manga',
      account: 'user',
      password: 'password',
    );

    expect(script.name, 'copy_manga_login.js');
    expect(script.code, contains('/api/v3/login'));
    expect(script.code, contains('previousToken'));
    expect(script.code, contains('Convert.encodeBase64'));
  });

  test('builds the Picacg response-tracing login workflow', () {
    final script = factory.build(
      sourceKey: 'picacg',
      account: 'user',
      password: 'password',
    );

    expect(script.name, 'source_login.js');
    expect(script.code, contains('authResponses'));
    expect(script.code, contains('/auth/sign-in'));
    expect(script.code, contains('Network.post = originalPost'));
  });
}
