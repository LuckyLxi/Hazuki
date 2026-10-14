import 'dart:convert';

class SourceLoginScript {
  const SourceLoginScript({required this.code, required this.name});

  final String code;
  final String name;
}

/// Encodes credentials for the plugin's standard account login entry point.
class SourceLoginScriptFactory {
  const SourceLoginScriptFactory();

  SourceLoginScript generic({
    required String account,
    required String password,
  }) => SourceLoginScript(
    code:
        'this.__hazuki_source.account.login(${jsonEncode(account)}, ${jsonEncode(password)})',
    name: 'source_login.js',
  );
}
