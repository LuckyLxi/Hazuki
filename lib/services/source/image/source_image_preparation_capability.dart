import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import '../common/source_json_coerce.dart';

import '../models/source_contract_models.dart';
import '../runtime/source_runtime_host.dart';

typedef SourceImageBytesDownloader =
    Future<Uint8List> Function(
      String url, {
      String? comicId,
      String? epId,
      bool keepInMemory,
      bool useDiskCache,
      bool priority,
      String sourceKey,
    });

/// Prepares source images without coupling the reader pipeline to the service
/// façade.
class SourceImagePreparationCapability {
  SourceImagePreparationCapability({
    required SourceRuntimeHost runtimeHost,
    required SourceImageBytesDownloader downloadImageBytes,
  }) : _runtimeHost = runtimeHost,
       _downloadImageBytes = downloadImageBytes;

  final SourceRuntimeHost _runtimeHost;
  final SourceImageBytesDownloader _downloadImageBytes;

  bool isLocalImagePath(String value) {
    final normalized = value.trim();
    if (normalized.startsWith('/') || normalized.startsWith('file://')) {
      return true;
    }
    return normalized.length >= 3 &&
        normalized[1] == ':' &&
        (normalized[2] == '\\' || normalized[2] == '/');
  }

  String normalizeLocalImagePath(String value) {
    final normalized = value.trim();
    return normalized.startsWith('file://')
        ? Uri.parse(normalized).toFilePath()
        : normalized;
  }

  Future<PreparedChapterImageData> prepareChapterImageData(
    String imageUrl, {
    required String comicId,
    required String epId,
    bool useDiskCache = true,
    bool priority = false,
    String sourceKey = '',
  }) async {
    var rawBytes = await _downloadImageBytes(
      imageUrl,
      comicId: comicId,
      epId: epId,
      keepInMemory: false,
      useDiskCache: useDiskCache,
      priority: priority,
      sourceKey: sourceKey,
    );
    final declaredSegments = await _resolveSourceDeclaredImageSegments(
      imageUrl,
      comicId: comicId,
      epId: epId,
      sourceKey: sourceKey,
    );
    var sourceExtension = imageExtensionFromUrl(imageUrl);
    var transformed = false;
    final handle = _runtimeHost.handleFor(_resolveSourceKey(sourceKey));
    final engine = handle.runtime.engine;
    if (engine?.evaluate(
          'typeof this.__hazuki_source.comic?.transformImageBytes === "function"',
        ) ==
        true) {
      final pending = engine!.invoke(
        '(bytes,url,id,ep)=>Promise.resolve(this.__hazuki_source.comic.transformImageBytes(new Uint8Array(bytes),url,id,ep)).then(result=>{const v=result?.bytes;return ArrayBuffer.isView(v)?{...result,bytes:v.buffer.slice(v.byteOffset,v.byteOffset+v.byteLength)}:result})',
        [rawBytes, imageUrl, comicId, epId],
      );
      final result = await handle.facade.js.resolve(pending);
      if (result is! Map || result['bytes'] == null) {
        throw StateError('plugin_invalid_image_transform');
      }
      rawBytes = jsToBytes(result['bytes']);
      if (rawBytes.isEmpty) throw StateError('plugin_empty_image_transform');
      final extension = result['extension']?.toString();
      if (extension != null) {
        if (!RegExp(r'^[a-zA-Z0-9]{1,8}$').hasMatch(extension)) {
          throw StateError('plugin_invalid_image_extension');
        }
        sourceExtension = extension.toLowerCase();
      }
      transformed = true;
    }
    final segments = declaredSegments != null && declaredSegments > 1
        ? declaredSegments
        : 0;
    if (segments > 1 && sourceExtension != 'gif') {
      final fixed = await _reverseVerticalImageTiles(
        rawBytes,
        segments,
        fallbackExtension: sourceExtension,
      );
      return PreparedChapterImageData(
        bytes: fixed.bytes,
        extension: fixed.extension,
        wasProcessed: true,
        aspectRatio: fixed.aspectRatio,
      );
    }
    return PreparedChapterImageData(
      bytes: rawBytes,
      extension: sourceExtension,
      wasProcessed: transformed,
    );
  }

  String _resolveSourceKey(String sourceKey) => sourceKey.trim().isEmpty
      ? _runtimeHost.activeSourceKey
      : _runtimeHost.normalize(sourceKey);

  Future<int?> _resolveSourceDeclaredImageSegments(
    String imageUrl, {
    required String comicId,
    required String epId,
    required String sourceKey,
  }) async {
    try {
      final facade = _runtimeHost
          .handleFor(_resolveSourceKey(sourceKey))
          .facade;
      final engine = facade.js.engine;
      if (engine == null) return null;
      final dynamic configRaw = engine.evaluate(
        'this.__hazuki_source.comic?.onImageLoad?.(${jsonEncode(imageUrl)}, ${jsonEncode(comicId)}, ${jsonEncode(epId)}) ?? {}',
        name: 'source_on_image_prepare.js',
      );
      return parseDeclaredImageSegments(await facade.js.resolve(configRaw));
    } catch (_) {
      return null;
    }
  }

  Future<({Uint8List bytes, String extension, double? aspectRatio})>
  _reverseVerticalImageTiles(
    Uint8List data,
    int segments, {
    required String fallbackExtension,
  }) async {
    final codec = await instantiateImageCodec(data);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final width = image.width;
    final height = image.height;
    final aspectRatio = height > 0 ? width / height : null;
    try {
      final src = await image.toByteData(format: ImageByteFormat.rawRgba);
      if (src == null) {
        return (
          bytes: data,
          extension: fallbackExtension,
          aspectRatio: aspectRatio,
        );
      }
      final blockSize = height ~/ segments;
      final remainder = height % segments;
      final srcBytes = src.buffer.asUint8List();
      final dstBytes = Uint8List(srcBytes.length);
      var destY = 0;
      for (var i = segments - 1; i >= 0; i--) {
        final startY = i * blockSize;
        final currentHeight = blockSize + (i == segments - 1 ? remainder : 0);
        final rowBytes = width * 4;
        for (var y = 0; y < currentHeight; y++) {
          final srcOffset = ((startY + y) * width) * 4;
          final dstOffset = ((destY + y) * width) * 4;
          dstBytes.setRange(
            dstOffset,
            dstOffset + rowBytes,
            srcBytes,
            srcOffset,
          );
        }
        destY += currentHeight;
      }
      final buffer = await ImmutableBuffer.fromUint8List(dstBytes);
      final descriptor = ImageDescriptor.raw(
        buffer,
        width: width,
        height: height,
        pixelFormat: PixelFormat.rgba8888,
        rowBytes: width * 4,
      );
      final outCodec = await descriptor.instantiateCodec();
      final outFrame = await outCodec.getNextFrame();
      final outImage = outFrame.image;
      try {
        final png = await outImage.toByteData(format: ImageByteFormat.png);
        if (png == null) {
          return (
            bytes: data,
            extension: fallbackExtension,
            aspectRatio: aspectRatio,
          );
        }
        return (
          bytes: png.buffer.asUint8List(),
          extension: 'png',
          aspectRatio: aspectRatio,
        );
      } finally {
        outImage.dispose();
      }
    } finally {
      image.dispose();
    }
  }

  @visibleForTesting
  static int? parseDeclaredImageSegments(dynamic config) {
    if (config is! Map) return null;
    final directSegments = config['segments'] ?? config['num'];
    if (directSegments is num) return directSegments.toInt();
    final directSegmentsText = directSegments?.toString().trim() ?? '';
    if (directSegmentsText.isNotEmpty) {
      final parsed = int.tryParse(directSegmentsText);
      if (parsed != null) return parsed;
    }
    final modifyImage = config['modifyImage']?.toString().trim() ?? '';
    if (modifyImage.isEmpty) return null;
    final match = RegExp(r'\bnum\s*=\s*(\d+)\b').firstMatch(modifyImage);
    return int.tryParse(match?.group(1) ?? '');
  }

  @visibleForTesting
  static String imageExtensionFromUrl(String imageUrl) {
    final uri = Uri.tryParse(imageUrl);
    final lastSegment = uri?.pathSegments.isNotEmpty == true
        ? uri!.pathSegments.last
        : imageUrl.split('/').last;
    final match = RegExp(
      r'\.([a-zA-Z0-9]+)(?:$|\?)',
      caseSensitive: false,
    ).firstMatch(lastSegment);
    final extension = match?.group(1)?.toLowerCase();
    return extension == null || extension.isEmpty ? 'jpg' : extension;
  }
}
