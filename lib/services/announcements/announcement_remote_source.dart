import 'package:dio/dio.dart';

import '../network/hazuki_network.dart';
import '../../shared/preferences/software_update_source.dart';

const _githubAnnouncementManifestUrl =
    'https://raw.githubusercontent.com/LuckyLxi/Hazuki/main/announcement.json';
const _jsDelivrAnnouncementManifestUrl =
    'https://cdn.jsdelivr.net/gh/LuckyLxi/Hazuki@main/announcement.json';
const _ghProxyBaseUrl = 'https://ghproxy.net/';

String resolveAnnouncementManifestUrl(SoftwareUpdateSource source) {
  return switch (source) {
    SoftwareUpdateSource.jsDelivr => _jsDelivrAnnouncementManifestUrl,
    SoftwareUpdateSource.github => _githubAnnouncementManifestUrl,
    SoftwareUpdateSource.ghproxy =>
      '$_ghProxyBaseUrl$_githubAnnouncementManifestUrl',
  };
}

typedef AnnouncementRemoteLoader = Future<String?> Function();

abstract interface class AnnouncementRemoteSource {
  Future<String?> loadManifest();
}

class CallbackAnnouncementRemoteSource implements AnnouncementRemoteSource {
  const CallbackAnnouncementRemoteSource(this._loader);

  final AnnouncementRemoteLoader _loader;

  @override
  Future<String?> loadManifest() async {
    try {
      return await _loader();
    } on DioException {
      return null;
    }
  }
}

class HttpAnnouncementRemoteSource implements AnnouncementRemoteSource {
  HttpAnnouncementRemoteSource({
    HazukiNetworkClient? client,
    Future<SoftwareUpdateSource> Function()? loadSource,
    DateTime Function()? now,
  }) : _client = client ?? _createClient(),
       _loadSource = loadSource ?? loadSoftwareUpdateSourcePreference,
       _now = now ?? DateTime.now;

  final HazukiNetworkClient _client;
  final Future<SoftwareUpdateSource> Function() _loadSource;
  final DateTime Function() _now;

  @override
  Future<String?> loadManifest() async {
    try {
      final source = await _loadSource();
      final manifestUrl = resolveAnnouncementManifestUrl(source);
      final cacheBuster = _now().millisecondsSinceEpoch;
      final response = await _client.get<String>(
        '$manifestUrl?ts=$cacheBuster',
        options: Options(headers: const {'Cache-Control': 'no-cache'}),
      );
      return response.data ?? '';
    } on DioException {
      return null;
    }
  }
}

HazukiNetworkClient _createClient() {
  return HazukiNetworkClient(
    dio: createHazukiDio(
      baseOptions: BaseOptions(
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 5),
        sendTimeout: const Duration(seconds: 3),
        responseType: ResponseType.plain,
        validateStatus: (status) =>
            status != null && status >= 200 && status < 300,
      ),
    ),
  );
}
