part of '../../hazuki_source_service.dart';

extension CookieStoreSupport on HazukiSourceService {
  Future<dynamic> _handleCookieOperationForHandle(
    SourceRuntimeHandleView handle,
    Map<String, dynamic> request,
  ) => handle.cookieStore.handleOperation(request);

  String? buildCookieHeader(String url) =>
      _activeHandle.cookieStore.buildHeader(url);

  String? buildCookieHeaderForHandle(
    SourceRuntimeHandleView handle,
    String url,
  ) => handle.cookieStore.buildHeader(url);

  Future<void> saveCookiesFromHeadersForHandle(
    SourceRuntimeHandleView handle,
    String url,
    Map<String, List<String>> headers,
  ) => handle.cookieStore.saveFromHeaders(url, headers);
}
