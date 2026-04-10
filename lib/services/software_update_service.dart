import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SoftwareUpdateService {
  SoftwareUpdateService._();

  static final SoftwareUpdateService instance = SoftwareUpdateService._();

  static const _updateManifestUrls = [
    'https://fastly.jsdelivr.net/gh/LuckyLxi/Hazuki@main/update.json',
    'https://gcore.jsdelivr.net/gh/LuckyLxi/Hazuki@main/update.json',
    'https://cdn.jsdelivr.net/gh/LuckyLxi/Hazuki@main/update.json',
    'https://raw.githubusercontent.com/LuckyLxi/Hazuki/main/update.json',
  ];

  static const _latestReleaseUrl =
      'https://api.github.com/repos/LuckyLxi/Hazuki/releases/latest';

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 3),
      receiveTimeout: const Duration(seconds: 4),
      sendTimeout: const Duration(seconds: 3),
      responseType: ResponseType.plain,
      headers: const {
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      },
      validateStatus: (status) =>
          status != null && status >= 200 && status < 300,
    ),
  );

  Future<SoftwareUpdateCheckResult?> checkForUpdates() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version.trim();

    final manifestData = await _loadUpdateManifest();
    if (manifestData != null) {
      final result = _buildResultFromManifest(
        manifestData,
        currentVersion: currentVersion,
      );
      if (result != null) {
        return result;
      }
    }

    final releaseData = await _loadLatestReleaseFromGitHubApi();
    if (releaseData == null) {
      return null;
    }

    return _buildResultFromRelease(releaseData, currentVersion: currentVersion);
  }

  Future<Map<String, dynamic>?> _loadUpdateManifest() async {
    for (final url in _updateManifestUrls) {
      final jsonMap = await _getJsonMap(url);
      if (jsonMap != null) {
        return jsonMap;
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> _loadLatestReleaseFromGitHubApi() async {
    return _getJsonMap(_latestReleaseUrl);
  }

  Future<Map<String, dynamic>?> _getJsonMap(String url) async {
    try {
      final response = await _dio.get<String>(url);
      final body = response.data?.trim();
      if (body == null || body.isEmpty) {
        return null;
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map) {
        return null;
      }
      return Map<String, dynamic>.from(decoded);
    } on DioException {
      return null;
    } on FormatException {
      return null;
    }
  }

  SoftwareUpdateCheckResult? _buildResultFromManifest(
    Map<String, dynamic> manifest, {
    required String currentVersion,
  }) {
    final latestVersionRaw = manifest['version']?.toString().trim();
    final releaseUrl = manifest['releaseUrl']?.toString().trim();
    final apkUrl = manifest['apkUrl']?.toString().trim();

    if (latestVersionRaw == null ||
        latestVersionRaw.isEmpty ||
        releaseUrl == null ||
        releaseUrl.isEmpty) {
      return null;
    }

    final latestVersion = _normalizeVersion(latestVersionRaw);
    return SoftwareUpdateCheckResult(
      currentVersion: currentVersion,
      latestVersion: latestVersion,
      releaseUrl: releaseUrl,
      apkUrl: apkUrl != null && apkUrl.isNotEmpty ? apkUrl : null,
      hasUpdate: _isVersionGreater(latestVersion, currentVersion),
    );
  }

  SoftwareUpdateCheckResult? _buildResultFromRelease(
    Map<String, dynamic> release, {
    required String currentVersion,
  }) {
    final latestVersionRaw =
        release['tag_name']?.toString().trim().isNotEmpty == true
        ? release['tag_name'].toString().trim()
        : release['name']?.toString().trim();
    final releaseUrl = release['html_url']?.toString().trim();
    final assets = release['assets'];

    String? apkUrl;
    if (assets is List) {
      for (final asset in assets) {
        if (asset is! Map) {
          continue;
        }
        final map = Map<String, dynamic>.from(asset);
        final name = map['name']?.toString().trim().toLowerCase() ?? '';
        final url = map['browser_download_url']?.toString().trim();
        if (!name.endsWith('.apk') || url == null || url.isEmpty) {
          continue;
        }
        if (name.contains('arm64-v8a')) {
          apkUrl = url;
          break;
        }
        apkUrl ??= url;
      }
    }

    if (latestVersionRaw == null ||
        latestVersionRaw.isEmpty ||
        releaseUrl == null ||
        releaseUrl.isEmpty) {
      return null;
    }

    final latestVersion = _normalizeVersion(latestVersionRaw);
    return SoftwareUpdateCheckResult(
      currentVersion: currentVersion,
      latestVersion: latestVersion,
      releaseUrl: releaseUrl,
      apkUrl: apkUrl,
      hasUpdate: _isVersionGreater(latestVersion, currentVersion),
    );
  }

  String _normalizeVersion(String version) {
    return version.trim().replaceFirst(RegExp(r'^[vV]'), '');
  }

  bool _isVersionGreater(String a, String b) {
    final pa = _parseVersionSegments(a);
    final pb = _parseVersionSegments(b);
    final len = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < len; i++) {
      final va = i < pa.length ? pa[i] : 0;
      final vb = i < pb.length ? pb[i] : 0;
      if (va > vb) {
        return true;
      }
      if (va < vb) {
        return false;
      }
    }
    return false;
  }

  List<int> _parseVersionSegments(String version) {
    final cleaned = version.trim().split('+').first.split('-').first;
    return cleaned.split('.').map((segment) {
      final match = RegExp(r'\d+').firstMatch(segment);
      return int.tryParse(match?.group(0) ?? '0') ?? 0;
    }).toList();
  }
}

class SoftwareUpdateCheckResult {
  const SoftwareUpdateCheckResult({
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseUrl,
    required this.hasUpdate,
    this.apkUrl,
  });

  final String currentVersion;
  final String latestVersion;
  final String releaseUrl;
  final String? apkUrl;
  final bool hasUpdate;
}
