import 'package:dio/dio.dart';

import '../../hazuki_source_service.dart';

class SourceHttpGateway {
  SourceHttpGateway(this._service, this._handle);

  final HazukiSourceService _service;
  final SourceRuntimeHandle _handle;

  Dio get dio => _handle.dio;

  String? buildCookieHeader(String url) =>
      _service.buildCookieHeaderForHandle(_handle, url);
}
