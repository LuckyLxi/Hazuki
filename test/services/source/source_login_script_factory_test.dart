import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/account/source_login_script_factory.dart';

void main() {
  test('encodes credentials for the standard plugin login entry point', () {
    const factory = SourceLoginScriptFactory();
    final script = factory.generic(
      account: 'user"name',
      password: 'line\nbreak',
    );
    expect(script.name, 'source_login.js');
    expect(script.code, contains(r'user\"name'));
    expect(script.code, contains(r'line\nbreak'));
    expect(script.code, startsWith('this.__hazuki_source.account.login('));
  });
}
