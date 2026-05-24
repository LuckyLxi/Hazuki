import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

Dio createHazukiDio({
  required BaseOptions baseOptions,
  bool configureIoAdapter = true,
}) {
  final dio = Dio(baseOptions);
  dio.transformer = _HazukiDioTransformer();
  if (configureIoAdapter) {
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () => HttpClient(),
    );
  }
  return dio;
}

class _HazukiDioTransformer extends FusedTransformer {
  @override
  Future<dynamic> transformResponse(
    RequestOptions options,
    ResponseBody responseBody,
  ) {
    final contentTypeValues = responseBody.headers[Headers.contentTypeHeader];
    if (contentTypeValues != null && contentTypeValues.isNotEmpty) {
      responseBody.headers[Headers.contentTypeHeader] = contentTypeValues
          .map(_normalizeContentType)
          .toList(growable: false);
    }
    return super.transformResponse(options, responseBody);
  }

  String _normalizeContentType(String contentType) {
    return contentType.trim().replaceFirst(RegExp(r'(;\s*)+$'), '');
  }
}
