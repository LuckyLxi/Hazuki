import '../models/source_task.dart';
import 'dart:convert' show jsonEncode;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import '../common/source_json_coerce.dart';

import '../models/source_contract_models.dart';
import '../runtime/source_runtime_host.dart';
import '../runtime/source_runtime_handle.dart';
import '../runtime/source_operation_context.dart';
import '../runtime/source_operation_runner.dart';

typedef SourceImageBytesDownloader =
    Future<Uint8List> Function(
      String url, {
      String? comicId,
      String? epId,
      bool keepInMemory,
      bool useDiskCache,
      bool priority,
      String sourceKey,
      SourceTaskOrigin? taskOrigin,
    });

/// 源图矩形 (sx, sy, sw, sh) 原尺寸搬运到画布 (dx, dy)。
typedef SourceImageRegion = ({int sx, int sy, int sw, int sh, int dx, int dy});

/// 插件声明的区域重排布局：输出画布尺寸与搬运区域列表。
typedef SourceImageRegionLayout = ({
  int width,
  int height,
  List<SourceImageRegion> regions,
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

  SourceReaderSession acquireReaderSession(String sourceKey) =>
      _runtimeHost.acquireReaderSession(sourceKey);

  SourceDownloadSession acquireDownloadSession(String sourceKey) =>
      _runtimeHost.acquireDownloadSession(sourceKey);

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
    SourceTaskOrigin? taskOrigin,
  }) async {
    taskOrigin?.readerSession?.checkActive();
    taskOrigin?.downloadSession?.checkActive();
    final resolvedKey = _resolveSourceKey(sourceKey);
    _runtimeHost.checkReaderSession(resolvedKey, taskOrigin);
    final handle = _runtimeHost.handleFor(resolvedKey);
    return runSourceOperation(
      _runtimeHost,
      handle,
      'reader.prepareImage',
      (context) async {
        var rawBytes = await context.runChild(
          _runtimeHost.tasks,
          (origin) => _downloadImageBytes(
            imageUrl,
            comicId: comicId,
            epId: epId,
            keepInMemory: false,
            useDiskCache: useDiskCache,
            priority: priority,
            sourceKey: resolvedKey,
            taskOrigin: origin,
          ),
          readerSession: taskOrigin?.readerSession,
          downloadSession: taskOrigin?.downloadSession,
        );
        context.checkActive();
        final declaredSegments = await _resolveSourceDeclaredImageSegments(
          imageUrl,
          comicId: comicId,
          epId: epId,
          handle: handle,
          context: context,
        );
        var sourceExtension = imageExtensionFromUrl(imageUrl);
        var transformed = false;
        final engine = handle.runtime.engine;
        if (engine != null &&
            await context.evaluate(
                  engine,
                  'typeof this.__hazuki_source.comic?.transformImageBytes === "function"',
                ) ==
                true) {
          final pending = await context.invoke(
            engine,
            '(bytes,url,id,ep)=>Promise.resolve(this.__hazuki_source.comic.transformImageBytes(new Uint8Array(bytes),url,id,ep)).then(result=>{const v=result?.bytes;return ArrayBuffer.isView(v)?{...result,bytes:v.buffer.slice(v.byteOffset,v.byteOffset+v.byteLength)}:result})',
            [rawBytes, imageUrl, comicId, epId],
          );
          final result = await context.resolve(
            handle.facade.js.resolve(pending),
          );
          if (result is! Map || result['bytes'] == null) {
            throw StateError('plugin_invalid_image_transform');
          }
          rawBytes = jsToBytes(result['bytes']);
          if (rawBytes.isEmpty) {
            throw StateError('plugin_empty_image_transform');
          }
          final extension = result['extension']?.toString();
          if (extension != null) {
            if (!RegExp(r'^[a-zA-Z0-9]{1,8}$').hasMatch(extension)) {
              throw StateError('plugin_invalid_image_extension');
            }
            sourceExtension = extension.toLowerCase();
          }
          transformed = true;
        }
        if (engine != null &&
            sourceExtension != 'gif' &&
            await context.evaluate(
                  engine,
                  'typeof this.__hazuki_source.comic?.mapImageRegions === "function"',
                ) ==
                true) {
          // 只读图片头取尺寸，插件据此计算区域；完整解码留到重排阶段。
          final size = await context.commit(() => _readImageSize(rawBytes));
          context.checkActive();
          final layoutRaw = await context.evaluate(
            engine,
            'this.__hazuki_source.comic.mapImageRegions(${size.width}, ${size.height}, ${jsonEncode(imageUrl)}, ${jsonEncode(comicId)}, ${jsonEncode(epId)}) ?? null',
            name: 'source_map_image_regions.js',
          );
          final layout = parseImageRegions(
            await context.resolve(handle.facade.js.resolve(layoutRaw)),
            sourceWidth: size.width,
            sourceHeight: size.height,
          );
          if (layout != null) {
            final fixed = await context.commit(
              () => _applyImageRegions(
                rawBytes,
                layout,
                fallbackExtension: sourceExtension,
                checkActive: context.checkActive,
              ),
            );
            context.checkActive();
            return PreparedChapterImageData(
              bytes: fixed.bytes,
              extension: fixed.extension,
              wasProcessed: true,
              aspectRatio: fixed.aspectRatio,
            );
          }
        }
        final segments = declaredSegments != null && declaredSegments > 1
            ? declaredSegments
            : 0;
        if (segments > 1 && sourceExtension != 'gif') {
          final fixed = await context.commit(
            () => _reverseVerticalImageTiles(
              rawBytes,
              segments,
              fallbackExtension: sourceExtension,
              checkActive: context.checkActive,
            ),
          );
          context.checkActive();
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
          aspectRatio: taskOrigin?.readerSession == null
              ? null
              : await context.commit(
                  () => _readAspectRatio(rawBytes, context.checkActive),
                ),
        );
      },
      origin: taskOrigin,
      retainOnSourceChange: taskOrigin == null,
      sensitiveValues: [imageUrl, comicId, epId],
    );
  }

  String _resolveSourceKey(String sourceKey) => sourceKey.trim().isEmpty
      ? _runtimeHost.activeSourceKey
      : _runtimeHost.normalize(sourceKey);

  Future<double> _readAspectRatio(
    Uint8List bytes,
    void Function() checkActive,
  ) async {
    try {
      final codec = await instantiateImageCodec(bytes);
      try {
        checkActive();
        final frame = await codec.getNextFrame();
        final image = frame.image;
        try {
          checkActive();
          if (image.height <= 0) {
            throw const SourceImageDecodeFailure();
          }
          return image.width / image.height;
        } finally {
          image.dispose();
        }
      } finally {
        codec.dispose();
      }
    } catch (error) {
      rethrowSourceOperationStop(error);
      throw const SourceImageDecodeFailure();
    }
  }

  Future<int?> _resolveSourceDeclaredImageSegments(
    String imageUrl, {
    required String comicId,
    required String epId,
    required SourceRuntimeHandle handle,
    required SourceOperationContext context,
  }) async {
    try {
      final facade = handle.facade;
      final engine = facade.js.engine;
      if (engine == null) return null;
      final dynamic configRaw = await context.evaluate(
        engine,
        'this.__hazuki_source.comic?.onImageLoad?.(${jsonEncode(imageUrl)}, ${jsonEncode(comicId)}, ${jsonEncode(epId)}) ?? {}',
        name: 'source_on_image_prepare.js',
      );
      return parseDeclaredImageSegments(
        await context.resolve(facade.js.resolve(configRaw)),
      );
    } catch (error) {
      rethrowSourceOperationStop(error);
      return null;
    }
  }

  Future<({Uint8List bytes, String extension, double? aspectRatio})>
  _reverseVerticalImageTiles(
    Uint8List data,
    int segments, {
    required String fallbackExtension,
    required void Function() checkActive,
  }) async {
    final codec = await instantiateImageCodec(data);
    Image? image;
    ImmutableBuffer? buffer;
    ImageDescriptor? descriptor;
    Codec? outCodec;
    Image? outImage;
    try {
      checkActive();
      final frame = await codec.getNextFrame();
      image = frame.image;
      checkActive();
      final width = image.width;
      final height = image.height;
      final aspectRatio = height > 0 ? width / height : null;
      final src = await image.toByteData(format: ImageByteFormat.rawRgba);
      if (src == null) {
        return (
          bytes: data,
          extension: fallbackExtension,
          aspectRatio: aspectRatio,
        );
      }
      checkActive();
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
      buffer = await ImmutableBuffer.fromUint8List(dstBytes);
      descriptor = ImageDescriptor.raw(
        buffer,
        width: width,
        height: height,
        pixelFormat: PixelFormat.rgba8888,
        rowBytes: width * 4,
      );
      checkActive();
      outCodec = await descriptor.instantiateCodec();
      final outFrame = await outCodec.getNextFrame();
      final decodedImage = outFrame.image;
      outImage = decodedImage;
      checkActive();
      final png = await decodedImage.toByteData(format: ImageByteFormat.png);
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
      outImage?.dispose();
      outCodec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
      image?.dispose();
      codec.dispose();
    }
  }

  Future<({int width, int height})> _readImageSize(Uint8List data) async {
    ImmutableBuffer? buffer;
    ImageDescriptor? descriptor;
    try {
      buffer = await ImmutableBuffer.fromUint8List(data);
      descriptor = await ImageDescriptor.encoded(buffer);
      if (descriptor.width <= 0 || descriptor.height <= 0) {
        throw const SourceImageDecodeFailure();
      }
      return (width: descriptor.width, height: descriptor.height);
    } catch (error) {
      rethrowSourceOperationStop(error);
      throw const SourceImageDecodeFailure();
    } finally {
      descriptor?.dispose();
      buffer?.dispose();
    }
  }

  Future<({Uint8List bytes, String extension, double? aspectRatio})>
  _applyImageRegions(
    Uint8List data,
    SourceImageRegionLayout layout, {
    required String fallbackExtension,
    required void Function() checkActive,
  }) async {
    final codec = await instantiateImageCodec(data);
    Image? image;
    ImmutableBuffer? buffer;
    ImageDescriptor? descriptor;
    Codec? outCodec;
    Image? outImage;
    try {
      checkActive();
      final frame = await codec.getNextFrame();
      image = frame.image;
      checkActive();
      final srcWidth = image.width;
      final src = await image.toByteData(format: ImageByteFormat.rawRgba);
      if (src == null) {
        throw const SourceImageDecodeFailure();
      }
      checkActive();
      final srcBytes = src.buffer.asUint8List();
      // 未被区域覆盖的画布像素保持全零，即透明。
      final dstBytes = Uint8List(layout.width * layout.height * 4);
      for (final region in layout.regions) {
        final rowBytes = region.sw * 4;
        for (var y = 0; y < region.sh; y++) {
          final srcOffset = ((region.sy + y) * srcWidth + region.sx) * 4;
          final dstOffset = ((region.dy + y) * layout.width + region.dx) * 4;
          dstBytes.setRange(
            dstOffset,
            dstOffset + rowBytes,
            srcBytes,
            srcOffset,
          );
        }
      }
      checkActive();
      buffer = await ImmutableBuffer.fromUint8List(dstBytes);
      descriptor = ImageDescriptor.raw(
        buffer,
        width: layout.width,
        height: layout.height,
        pixelFormat: PixelFormat.rgba8888,
        rowBytes: layout.width * 4,
      );
      outCodec = await descriptor.instantiateCodec();
      final outFrame = await outCodec.getNextFrame();
      outImage = outFrame.image;
      checkActive();
      final png = await outImage.toByteData(format: ImageByteFormat.png);
      if (png == null) {
        throw const SourceImageDecodeFailure();
      }
      return (
        bytes: png.buffer.asUint8List(),
        extension: 'png',
        aspectRatio: layout.width / layout.height,
      );
    } finally {
      outImage?.dispose();
      outCodec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
      image?.dispose();
      codec.dispose();
    }
  }

  /// 校验插件返回的区域布局；返回 null 表示插件不处理该图。
  ///
  /// 插件可能绕过 SDK 直接返回对象，因此所有边界在宿主侧重新校验。
  @visibleForTesting
  static SourceImageRegionLayout? parseImageRegions(
    dynamic raw, {
    required int sourceWidth,
    required int sourceHeight,
  }) {
    if (raw == null) return null;
    if (raw is! Map) throw StateError('plugin_invalid_image_regions');
    int? strictInt(dynamic value) {
      if (value is int) return value;
      if (value is num && value.isFinite && value == value.truncate()) {
        return value.toInt();
      }
      return null;
    }

    final width = raw['width'] == null ? sourceWidth : strictInt(raw['width']);
    final height = raw['height'] == null
        ? sourceHeight
        : strictInt(raw['height']);
    final rawRegions = raw['regions'];
    if (width == null ||
        height == null ||
        width <= 0 ||
        height <= 0 ||
        width * height > sourceWidth * sourceHeight * 4 ||
        rawRegions is! List ||
        rawRegions.length > 4096) {
      throw StateError('plugin_invalid_image_regions');
    }
    if (rawRegions.isEmpty) return null;
    final regions = <SourceImageRegion>[];
    for (final item in rawRegions) {
      if (item is! Map) throw StateError('plugin_invalid_image_regions');
      final sx = strictInt(item['sx']);
      final sy = strictInt(item['sy']);
      final sw = strictInt(item['sw']);
      final sh = strictInt(item['sh']);
      final dx = strictInt(item['dx']);
      final dy = strictInt(item['dy']);
      if (sx == null ||
          sy == null ||
          sw == null ||
          sh == null ||
          dx == null ||
          dy == null ||
          sx < 0 ||
          sy < 0 ||
          dx < 0 ||
          dy < 0 ||
          sw <= 0 ||
          sh <= 0 ||
          sx + sw > sourceWidth ||
          sy + sh > sourceHeight ||
          dx + sw > width ||
          dy + sh > height) {
        throw StateError('plugin_invalid_image_regions');
      }
      regions.add((sx: sx, sy: sy, sw: sw, sh: sh, dx: dx, dy: dy));
    }
    return (width: width, height: height, regions: regions);
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
