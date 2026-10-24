import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart' hide ZLibDecoder;
import 'package:dio/dio.dart';

/// 从远程 zip（含 aar）中只下载一个条目并解压到 [output]。
///
/// 优先用 HTTP Range 读取中央目录和该条目的数据段，流量只有条目的压缩大小；
/// 服务器不支持分段、遇到 ZIP64 或结构无法解析时，退回整包下载到 [scratch]
/// 再提取。网络错误以 [DioException] 抛出，由调用方决定是否换下载源。
Future<void> downloadZipEntry({
  required Dio dio,
  required String url,
  required int archiveBytes,
  required String entry,
  required File output,
  required File scratch,
  CancelToken? cancelToken,
  void Function(int received, int total)? onProgress,
}) async {
  try {
    await _downloadByRanges(
      dio,
      url,
      archiveBytes,
      entry,
      output,
      cancelToken,
      onProgress,
    );
    return;
  } on _RangeUnavailable {
    // 退回整包下载。
  } on FormatException {
    // 退回整包下载。
  }
  if (await output.exists()) await output.delete();
  await dio.download(
    url,
    scratch.path,
    cancelToken: cancelToken,
    deleteOnError: true,
    onReceiveProgress: onProgress,
  );
  if (cancelToken?.isCancelled ?? false) return;
  final found = await _extractInIsolate(scratch.path, entry, output.path);
  if (await scratch.exists()) await scratch.delete();
  if (!found) throw const FormatException('Archive entry not found');
}

class _RangeUnavailable implements Exception {
  const _RangeUnavailable();
}

const _tailBytes = 66 * 1024;
const _endOfCentralDirectory = 0x06054b50;
const _centralDirectoryEntry = 0x02014b50;
const _localFileHeader = 0x04034b50;

Future<void> _downloadByRanges(
  Dio dio,
  String url,
  int archiveBytes,
  String entry,
  File output,
  CancelToken? cancelToken,
  void Function(int received, int total)? onProgress,
) async {
  final tailStart = archiveBytes > _tailBytes ? archiveBytes - _tailBytes : 0;
  final tail = await _readRange(
    dio,
    url,
    tailStart,
    archiveBytes - 1,
    cancelToken,
  );
  var end = -1;
  for (var offset = tail.length - 22; offset >= 0; offset--) {
    if (_u32(tail, offset) == _endOfCentralDirectory) {
      end = offset;
      break;
    }
  }
  if (end < 0) throw const FormatException('End of central directory');
  final directorySize = _u32(tail, end + 12);
  final directoryOffset = _u32(tail, end + 16);
  // ZIP64 用 0xFFFFFFFF 占位，交给整包解压处理。
  if (directoryOffset == 0xffffffff || directorySize == 0xffffffff) {
    throw const _RangeUnavailable();
  }
  final directory = directoryOffset >= tailStart
      ? Uint8List.sublistView(
          tail,
          directoryOffset - tailStart,
          directoryOffset - tailStart + directorySize,
        )
      : await _readRange(
          dio,
          url,
          directoryOffset,
          directoryOffset + directorySize - 1,
          cancelToken,
        );
  final record = _findEntry(directory, entry);
  if (record == null) throw const FormatException('Archive entry not found');
  final (method, compressedSize, localOffset) = record;
  if (method != 0 && method != 8) {
    throw const FormatException('Unsupported compression method');
  }
  final header = await _readRange(
    dio,
    url,
    localOffset,
    localOffset + 29,
    cancelToken,
  );
  if (_u32(header, 0) != _localFileHeader) {
    throw const FormatException('Local file header');
  }
  final dataStart = localOffset + 30 + _u16(header, 26) + _u16(header, 28);
  final response = await _request(
    dio,
    url,
    dataStart,
    dataStart + compressedSize - 1,
    cancelToken,
  );
  await output.parent.create(recursive: true);
  final sink = output.openWrite();
  try {
    var received = 0;
    final compressed = response.stream.map((chunk) {
      received += chunk.length;
      onProgress?.call(received, compressedSize);
      return chunk;
    });
    final decoded = method == 8
        ? compressed.cast<List<int>>().transform(ZLibDecoder(raw: true))
        : compressed;
    await sink.addStream(decoded);
    await sink.flush();
  } finally {
    await sink.close();
  }
}

(int, int, int)? _findEntry(Uint8List directory, String entry) {
  var offset = 0;
  while (offset + 46 <= directory.length &&
      _u32(directory, offset) == _centralDirectoryEntry) {
    final nameLength = _u16(directory, offset + 28);
    final extraLength = _u16(directory, offset + 30);
    final commentLength = _u16(directory, offset + 32);
    final name = String.fromCharCodes(
      directory,
      offset + 46,
      offset + 46 + nameLength,
    );
    if (name == entry) {
      final compressedSize = _u32(directory, offset + 20);
      final localOffset = _u32(directory, offset + 42);
      if (compressedSize == 0xffffffff || localOffset == 0xffffffff) {
        throw const _RangeUnavailable();
      }
      return (_u16(directory, offset + 10), compressedSize, localOffset);
    }
    offset += 46 + nameLength + extraLength + commentLength;
  }
  return null;
}

Future<Uint8List> _readRange(
  Dio dio,
  String url,
  int start,
  int end,
  CancelToken? cancelToken,
) async {
  final response = await _request(dio, url, start, end, cancelToken);
  final builder = BytesBuilder(copy: false);
  await for (final chunk in response.stream) {
    builder.add(chunk);
  }
  final bytes = builder.takeBytes();
  if (bytes.length != end - start + 1) {
    throw const FormatException('Unexpected range length');
  }
  return bytes;
}

/// 发送区间请求并逐跳处理重定向，保证每一跳都携带 Range 头。
Future<ResponseBody> _request(
  Dio dio,
  String url,
  int start,
  int end,
  CancelToken? cancelToken,
) async {
  var target = Uri.parse(url);
  for (var hop = 0; hop < 6; hop++) {
    final response = await dio.getUri<ResponseBody>(
      target,
      cancelToken: cancelToken,
      options: Options(
        headers: {HttpHeaders.rangeHeader: 'bytes=$start-$end'},
        followRedirects: false,
        responseType: ResponseType.stream,
        validateStatus: (status) =>
            status != null && status >= 200 && status < 400,
      ),
    );
    final status = response.statusCode!;
    final body = response.data!;
    if (status == HttpStatus.partialContent) return body;
    // 只取到响应头就关闭连接，避免服务器忽略 Range 时下载整个文件。
    unawaited(body.stream.listen(null).cancel());
    final location = response.headers.value(HttpHeaders.locationHeader);
    if (status < 300 || location == null) throw const _RangeUnavailable();
    target = target.resolve(location);
  }
  throw const _RangeUnavailable();
}

int _u16(Uint8List bytes, int offset) => bytes[offset] | bytes[offset + 1] << 8;

int _u32(Uint8List bytes, int offset) =>
    _u16(bytes, offset) | _u16(bytes, offset + 2) << 16;

// 闭包在顶层函数中创建，避免捕获无法发送到工作 isolate 的上下文。
Future<bool> _extractInIsolate(String archive, String entry, String output) =>
    Isolate.run(() {
      final input = InputFileStream(archive);
      try {
        for (final file in ZipDecoder().decodeStream(input).files) {
          if (!file.isFile || file.name != entry) continue;
          final stream = OutputFileStream(output);
          try {
            file.writeContent(stream);
          } finally {
            stream.closeSync();
          }
          return true;
        }
        return false;
      } finally {
        input.closeSync();
      }
    });
