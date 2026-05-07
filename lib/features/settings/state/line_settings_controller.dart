import 'package:flutter/foundation.dart';
import 'package:hazuki/services/hazuki_source_service.dart';

class LineSettingsController extends ChangeNotifier {
  LineSettingsController({HazukiSourceService? sourceService})
    : _sourceService = sourceService ?? HazukiSourceService.instance;

  final HazukiSourceService _sourceService;

  bool _loading = true;
  bool _refreshingStatus = false;

  String _selectedApiDomain = '1';
  String _selectedImageStream = '1';
  bool _refreshDomainsOnStart = true;

  List<String> _apiDomains = const [];
  int _imageStreamCount = 4;
  String _currentImageHost = '';

  bool _disposed = false;

  bool get loading => _loading;
  bool get refreshingStatus => _refreshingStatus;
  String get selectedApiDomain => _selectedApiDomain;
  String get selectedImageStream => _selectedImageStream;
  bool get refreshDomainsOnStart => _refreshDomainsOnStart;
  List<String> get apiDomains => _apiDomains;
  int get imageStreamCount => _imageStreamCount;
  String get currentImageHost => _currentImageHost;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> loadSnapshot({bool showLoading = true}) async {
    if (_disposed) return;
    if (showLoading) {
      _loading = true;
      _notify();
    }

    try {
      final snapshot = await _sourceService
          .getLineSettingsSnapshot()
          .timeout(const Duration(seconds: 20));
      if (_disposed) return;

      final apiDomainsRaw = snapshot['apiDomains'];
      final apiDomains = <String>[];
      if (apiDomainsRaw is List) {
        for (final item in apiDomainsRaw) {
          final text = item?.toString().trim() ?? '';
          if (text.isNotEmpty) {
            apiDomains.add(text);
          }
        }
      }

      final imageCountRaw = snapshot['imageStreamOptionsCount'];
      final parsedImageCount = switch (imageCountRaw) {
        int value => value,
        num value => value.toInt(),
        _ => int.tryParse(imageCountRaw?.toString() ?? ''),
      };

      final apiCount = apiDomains.isEmpty ? 4 : apiDomains.length;
      var selectedApi = snapshot['apiDomain']?.toString() ?? '1';
      final selectedApiInt = int.tryParse(selectedApi);
      if (selectedApiInt == null ||
          selectedApiInt < 1 ||
          selectedApiInt > apiCount) {
        selectedApi = '1';
      }

      final imageCount = (parsedImageCount ?? 4).clamp(1, 8);
      var selectedImage = snapshot['imageStream']?.toString() ?? '1';
      final selectedImageInt = int.tryParse(selectedImage);
      if (selectedImageInt == null ||
          selectedImageInt < 1 ||
          selectedImageInt > imageCount) {
        selectedImage = '1';
      }

      _selectedApiDomain = selectedApi;
      _selectedImageStream = selectedImage;
      _refreshDomainsOnStart = snapshot['refreshDomainsOnStart'] == true;
      _apiDomains = apiDomains;
      _imageStreamCount = imageCount;
      _currentImageHost = snapshot['imageHost']?.toString() ?? '';
    } finally {
      if (!_disposed && showLoading) {
        _loading = false;
      }
      _notify();
    }
  }

  Future<void> refreshLineStatus() async {
    if (_disposed || _refreshingStatus) return;
    _refreshingStatus = true;
    _notify();
    try {
      await _sourceService.refreshLines();
      await loadSnapshot(showLoading: false);
    } finally {
      if (!_disposed) {
        _refreshingStatus = false;
        _notify();
      }
    }
  }

  Future<void> setApiDomain(String value) async {
    if (value == _selectedApiDomain) return;
    _selectedApiDomain = value;
    _notify();
    await _sourceService.updateLineSetting('apiDomain', value);
    await _sourceService.refreshLines(
      refreshApiDomains: false,
      refreshImageHost: false,
    );
  }

  Future<void> setImageStream(String value) async {
    if (value == _selectedImageStream) return;
    _selectedImageStream = value;
    _notify();
    await _sourceService.updateLineSetting('imageStream', value);
    await _sourceService.refreshLines(
      refreshApiDomains: false,
      refreshImageHost: true,
    );
    await loadSnapshot();
  }

  Future<void> setRefreshDomainsOnStart(bool value) async {
    _refreshDomainsOnStart = value;
    _notify();
    await _sourceService.updateLineSetting('refreshDomainsOnStart', value);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
