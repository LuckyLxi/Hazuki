import 'package:dio/dio.dart';

import '../../hazuki_source_service.dart';

class SourceHttpGateway {
  SourceHttpGateway(this._service);

  final HazukiSourceService _service;

  Dio get dio => _service.dio;

  String? buildCookieHeader(String url) => _service.buildCookieHeader(url);
}
