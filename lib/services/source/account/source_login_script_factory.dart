import 'dart:convert';

import '../models/source_identity.dart';

class SourceLoginScript {
  const SourceLoginScript({required this.code, required this.name});

  final String code;
  final String name;
}

/// Builds the source-specific JavaScript used to authenticate an account.
class SourceLoginScriptFactory {
  const SourceLoginScriptFactory();

  SourceLoginScript build({
    required String sourceKey,
    required String account,
    required String password,
  }) {
    if (isHazukiCopyMangaSourceKey(sourceKey)) {
      return SourceLoginScript(
        code: _copyMangaLoginScript(account: account, password: password),
        name: 'copy_manga_login.js',
      );
    }
    if (isHazukiPicacgSourceKey(sourceKey)) {
      return SourceLoginScript(
        code: _picacgLoginWithResponseTraceScript(
          account: account,
          password: password,
        ),
        name: 'source_login.js',
      );
    }
    return SourceLoginScript(
      code:
          'this.__hazuki_source.account.login(${jsonEncode(account)}, ${jsonEncode(password)})',
      name: 'source_login.js',
    );
  }
}

String _picacgLoginWithResponseTraceScript({
  required String account,
  required String password,
}) {
  final accountJson = jsonEncode(account);
  final passwordJson = jsonEncode(password);
  return '''
(async () => {
  const source = this.__hazuki_source;
  const originalPost = Network.post;
  const authResponses = [];
  Network.post = async function(url, headers, data) {
    const response = await originalPost.call(Network, url, headers, data);
    const urlText = String(url || "");
    if (urlText.includes("/auth/sign-in") || urlText.includes("auth/sign-in")) {
      let parsedBody = null;
      try {
        parsedBody = JSON.parse(response && response.body);
      } catch (_) {}
      authResponses.push({
        url: urlText,
        status: response && response.status,
        headers: response && response.headers,
        body: response && response.body,
        parsedBody: parsedBody
      });
    }
    return response;
  };
  try {
    const loginResult = await source.account.login($accountJson, $passwordJson);
    return {
      loginResult: loginResult,
      authResponses: authResponses
    };
  } finally {
    Network.post = originalPost;
  }
})()
''';
}

String _copyMangaLoginScript({
  required String account,
  required String password,
}) {
  final accountJson = jsonEncode(account);
  final passwordJson = jsonEncode(password);
  return '''
(async () => {
  const source = this.__hazuki_source;
  const account = $accountJson;
  const password = $passwordJson;
  const previousToken = source.loadData("token");
  const salt = Math.floor(Math.random() * 9000) + 1000;
  const encodedPassword = Convert.encodeBase64(
    Convert.encodeUtf8(password + "-" + salt)
  );
  const headers = {
    ...source.headers,
    "Content-Type": "application/x-www-form-urlencoded;charset=utf-8"
  };
  const body =
    "username=" +
    account +
    "&password=" +
    encodedPassword +
    "\\n&salt=" +
    salt +
    "&authorization=Token+";
  const response = await Network.post(
    source.apiUrl + "/api/v3/login",
    headers,
    body
  );
  if (response.status !== 200) {
    if (previousToken) {
      source.saveData("token", previousToken);
    }
    throw "Invalid Status Code " + response.status;
  }
  const data = JSON.parse(response.body);
  const token = data && data.results && data.results.token;
  if (token) {
    source.saveData("token", token);
  }
  return data;
})()
''';
}
