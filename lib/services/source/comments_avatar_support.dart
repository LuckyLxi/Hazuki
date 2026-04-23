part of '../hazuki_source_service.dart';

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

    final baseUrl = facade.js.evaluateString('this.__hazuki_source.baseUrl');
    final imageUrl = facade.js.evaluateString('this.__hazuki_source.imageUrl');
    if (baseUrl.isEmpty) {
      return null;
    }

    final baseUri = Uri.tryParse(baseUrl);
    if (baseUri == null || !baseUri.hasScheme || baseUri.host.isEmpty) {
      return null;
    }

    final imageBaseUri = facade.resolveImageBaseUri(imageUrl, baseUri);

    try {
      final storedUidRaw = facade.js.evaluate(
        'this.__hazuki_source.loadData("uid")',
      );
      final storedUid = (await facade.js.resolve(storedUidRaw) ?? '')
          .toString()
          .trim();
      if (RegExp(r'^\d+$').hasMatch(storedUid)) {
        return imageBaseUri.resolve('/media/users/$storedUid.jpg').toString();
      }
    } catch (_) {}

    return null;
  }
}
