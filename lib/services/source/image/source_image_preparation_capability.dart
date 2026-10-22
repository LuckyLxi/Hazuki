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
