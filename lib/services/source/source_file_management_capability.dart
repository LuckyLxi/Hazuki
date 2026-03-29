part of '../hazuki_source_service.dart';

extension HazukiSourceServiceSourceFileManagementCapability
    on HazukiSourceService {
  Future<String> loadEditableJmSource() async {
    final result = await _downloadOrLoadSourceFiles();
    return result.jmFile.readAsString();
  }

  Future<void> saveEditedJmSource(String content) async {
    final result = await _downloadOrLoadSourceFiles();
    await result.jmFile.writeAsString(content, flush: true);
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    await prefs.setBool(HazukiSourceService._customEditedJmSourceKey, true);
    _lastSourceVersionDebugInfo = {
      'checkedAt': DateTime.now().toIso8601String(),
      'resolvedFrom': 'local_source_editor',
      'outcome': 'edited_waiting_for_restart',
    };
    _statusText = 'source_edited_waiting_for_restart';
  }

  Future<bool> hasLocalJmSourceFile() async {
    final sourceDir = await _getSourceStorageDirectory();
    final jmFile = File('${sourceDir.path}/jm.js');
    return jmFile.exists();
  }

  Future<bool> hasCustomEditedJmSource() async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    return prefs.getBool(HazukiSourceService._customEditedJmSourceKey) ?? false;
  }

  Future<Directory> _getSourceStorageDirectory() async {
    if (Platform.isAndroid) {
      final supportDir = await getApplicationSupportDirectory();
      return Directory('${supportDir.path}/comic_source');
    }

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null) {
        return Directory('${downloadsDir.path}/hazuki_source_test');
      }
    }

    final documentsDir = await getApplicationDocumentsDirectory();
    return Directory('${documentsDir.path}/comic_source');
  }
}
