part of '../hazuki_source_service.dart';

extension HazukiSourceServiceCommentsAvatarSupport on HazukiSourceService {
  Future<String?> loadCurrentAvatarUrl() async {
    if (!isLogged) {
      return null;
    }

    final engine = _engine;
    if (engine == null) {
      return null;
    }

    final baseUrl = (engine.evaluate('this.__hazuki_source.baseUrl') ?? '')
        .toString()
        .trim();
    final imageUrl = (engine.evaluate('this.__hazuki_source.imageUrl') ?? '')
        .toString()
        .trim();
    if (baseUrl.isEmpty) {
      return null;
    }

    final baseUri = Uri.tryParse(baseUrl);
    if (baseUri == null || !baseUri.hasScheme || baseUri.host.isEmpty) {
      return null;
    }

    final imageBaseUri = _resolveImageBaseUri(imageUrl, baseUri);

    try {
      final storedUidRaw = engine.evaluate(
        'this.__hazuki_source.loadData("uid")',
      );
      final storedUid = (await _awaitJsResult(storedUidRaw) ?? '')
          .toString()
          .trim();
      if (RegExp(r'^\d+$').hasMatch(storedUid)) {
        return imageBaseUri.resolve('/media/users/$storedUid.jpg').toString();
      }
    } catch (_) {}

    return null;
  }

  Uri _resolveImageBaseUri(String imageUrl, Uri baseUri) {
    final imageUri = Uri.tryParse(imageUrl);
    if (imageUri != null && imageUri.hasScheme && imageUri.host.isNotEmpty) {
      return imageUri;
    }
    return baseUri;
  }
}
