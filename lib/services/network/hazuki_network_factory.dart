import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

Dio createHazukiDio({
  required BaseOptions baseOptions,
  bool configureIoAdapter = true,
}) {
  final dio = Dio(baseOptions);
  if (configureIoAdapter) {
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () => HttpClient(),
    );
  }
  return dio;
}
