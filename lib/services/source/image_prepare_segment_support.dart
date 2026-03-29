part of '../hazuki_source_service.dart';

extension HazukiSourceServiceImagePrepareSegmentSupport on HazukiSourceService {
  int calculateJmImageSegments(String epId, String imageUrl) {
    if ((_sourceMeta?.key ?? '').toLowerCase() != 'jm') {
      return 0;
    }

    const scrambleId = 220980;
    final id = int.tryParse(epId) ?? 0;
    if (id < scrambleId) {
      return 0;
    }
    if (id < 268850) {
      return 10;
    }

    final pictureName = _extractJmPictureName(imageUrl);
    final digest = md5.convert(utf8.encode('$id$pictureName')).toString();
    final charCode = digest.codeUnitAt(digest.length - 1);

    if (id > 421926) {
      final remainder = charCode % 8;
      return remainder * 2 + 2;
    }
    final remainder = charCode % 10;
    return remainder * 2 + 2;
  }

  String _extractJmPictureName(String imageUrl) {
    final normalizedUrl = imageUrl.trim();
    final slashIndex = normalizedUrl.lastIndexOf('/');
    final lastSegment = slashIndex >= 0
        ? normalizedUrl.substring(slashIndex + 1)
        : normalizedUrl;
    if (lastSegment.length > 5) {
      return lastSegment.substring(0, lastSegment.length - 5);
    }
    final dotIndex = lastSegment.lastIndexOf('.');
    if (dotIndex > 0) {
      return lastSegment.substring(0, dotIndex);
    }
    return lastSegment;
  }

  Future<int?> _resolveSourceDeclaredImageSegments(
    String imageUrl, {
    required String comicId,
    required String epId,
  }) async {
    try {
      final engine = _engine;
      if (engine == null) {
        return null;
      }
      final dynamic configRaw = engine.evaluate(
        'this.__hazuki_source.comic?.onImageLoad?.(${jsonEncode(imageUrl)}, ${jsonEncode(comicId)}, ${jsonEncode(epId)}) ?? {}',
        name: 'source_on_image_prepare.js',
      );
      final dynamic config = await _awaitJsResult(configRaw);
      if (config is! Map) {
        return null;
      }
      final modifyImage = config['modifyImage']?.toString().trim() ?? '';
      if (modifyImage.isEmpty) {
        return 0;
      }
      final match = RegExp(
        r'(?:const|let|var)\s+num\s*=\s*(\d+)\b',
      ).firstMatch(modifyImage);
      return int.tryParse(match?.group(1) ?? '');
    } catch (_) {
      return null;
    }
  }
}
