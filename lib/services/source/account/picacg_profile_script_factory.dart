import 'dart:convert';

/// Builds the signed Picacg profile request executed by the source engine.
class PicacgProfileScriptFactory {
  const PicacgProfileScriptFactory();

  String build(String token) {
    final tokenJson = jsonEncode(token);
    return '''
(async () => {
  const source = this.__hazuki_source;
  const token = $tokenJson;
  const baseUrl = source.loadSetting("base_url") || "https://picaapi.picacomic.com";
  if (!baseUrl || !source.createSignature) {
    return { ok: false, reason: "missing_profile_request_support" };
  }
  const path = "/users/profile";
  const unsignedPath = "users/profile";
  const method = "GET";
  const requestBaseUrl = baseUrl.endsWith("/")
    ? baseUrl.slice(0, -1)
    : baseUrl;
  async function requestProfile(signaturePath) {
    const uuid = createUuid();
    const nonce = uuid.replace(/-/g, "");
    const time = (new Date().getTime() / 1000).toFixed(0);
    const signature = source.createSignature(signaturePath, nonce, time, method);
    const headers = {
      "time": time,
      "nonce": nonce,
      "signature": signature,
      "accept": "application/vnd.picacomic.com.v1+json",
      "api-key": "C69BAF41DA5ABD1FFEDC6D2FEA56B",
      "app-channel": "2",
      "app-version": "2.2.1.2.3.3",
      "app-uuid": uuid,
      "app-platform": "android",
      "app-build-version": "44",
      "image-quality": "original",
      "user-agent": "okhttp/3.8.1",
      "version": "v1.4.1",
      "Host": "picaapi.picacomic.com",
      "Content-Type": "application/json; charset=UTF-8",
      "authorization": token
    };
    const response = await Network.get(requestBaseUrl + path, headers);
    let parsedBody = null;
    try {
      parsedBody = JSON.parse(response && response.body);
    } catch (_) {}
    return {
      ok: response && response.status === 200,
      status: response && response.status,
      path,
      signaturePath,
      requestUrl: requestBaseUrl + path,
      body: response && response.body,
      parsedBody
    };
  }
  const attempts = [await requestProfile(path), await requestProfile(unsignedPath)];
  const withAvatar = attempts.find((item) => {
    const body = item && item.parsedBody;
    const data = body && body.data;
    const user = data && data.user;
    return (user && user.avatar) || (data && data.avatar) || (body && body.avatar);
  });
  const selected = withAvatar || attempts[0];
  return {
    ...selected,
    attempts
  };
})()
''';
  }
}
