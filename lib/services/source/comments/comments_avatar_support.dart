part of '../../hazuki_source_service.dart';

extension HazukiSourceServiceCommentsAvatarSupport on HazukiSourceService {
  Future<String?> loadCurrentAvatarUrl() async {
    final facade = this.facade;
    if (!facade.isLogged) {
      return null;
    }

    final engine = facade.js.engine;
    if (engine == null) {
      return null;
    }

    // 优先读取本地缓存的头像 URL（由 _tryFetchAvatarViaApi 写入）
    try {
      final cachedRaw = facade.js.evaluate(
        'this.__hazuki_source.loadData("avatar_url")',
      );
      final cached = (await facade.js.resolve(cachedRaw))?.toString().trim();
      if (cached != null && cached.isNotEmpty) {
        return cached;
      }
    } catch (_) {}

    // JM 源的头像 URL 构造方式（通过 uid + baseUrl 拼接）
    final baseUrl = facade.js.evaluateString('this.__hazuki_source.baseUrl');
    final imageUrl = facade.js.evaluateString('this.__hazuki_source.imageUrl');
    if (baseUrl.isNotEmpty) {
      final baseUri = Uri.tryParse(baseUrl);
      if (baseUri != null && baseUri.hasScheme && baseUri.host.isNotEmpty) {
        final imageBaseUri = facade.resolveImageBaseUri(imageUrl, baseUri);
        try {
          final storedUidRaw = facade.js.evaluate(
            'this.__hazuki_source.loadData("uid")',
          );
          final storedUid = (await facade.js.resolve(storedUidRaw) ?? '')
              .toString()
              .trim();
          if (RegExp(r'^\d+$').hasMatch(storedUid)) {
            return imageBaseUri
                .resolve('/media/users/$storedUid.jpg')
                .toString();
          }
        } catch (_) {}
      }
    }

    // 兜底：通过 JS 引擎调用源的 /api/v3/me 接口动态获取头像 URL，
    // 适用于拷贝漫画等拥有 apiUrl 属性但不使用 JM 风格头像的源
    return _tryFetchAvatarViaApi(engine, facade);
  }

  /// 通过 JS 引擎调用 /api/v3/me 接口获取头像 URL 并写入本地缓存
  Future<String?> _tryFetchAvatarViaApi(
    // ignore: avoid_dynamic_calls
    dynamic engine,
    HazukiSourceFacade facade,
  ) async {
    final sourceMeta = facade.sourceMeta;
    if (sourceMeta == null) {
      return null;
    }

    try {
      // 使用 JS 引擎调用，自动携带源实现的请求签名头（含 token）
      final result = engine.evaluate(r'''
        (async () => {
          try {
            let apiUrl = this.__hazuki_source.apiUrl;
            if (!apiUrl) return null;
            let res = await Network.get(
              apiUrl + "/api/v3/me",
              this.__hazuki_source.headers
            );
            if (res.status !== 200) return null;
            let data = JSON.parse(res.body);
            let r = data && data.results;
            if (!r) return null;
            // 尝试多个常见的头像字段名
            return r.avatar
              || r.user_cover
              || r.cover
              || r.avatar_url
              || r.user_avatar
              || null;
          } catch (_) {
            return null;
          }
        })()
        ''', name: 'fetch_avatar_url.js');

      final resolved = await facade.js.resolve(result);
      final avatarUrl = resolved?.toString().trim();

      if (avatarUrl != null &&
          avatarUrl.isNotEmpty &&
          avatarUrl.startsWith('http')) {
        // 写入本地缓存，下次直接读取，无需重复请求
        await facade.saveSourceData(sourceMeta.key, 'avatar_url', avatarUrl);
        return avatarUrl;
      }
    } catch (_) {}

    return null;
  }
}
