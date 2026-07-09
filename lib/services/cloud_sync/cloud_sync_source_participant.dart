import '../source/source_capabilities.dart';

class CloudSyncSourceParticipant {
  const CloudSyncSourceParticipant(this._source);

  final SourceSyncGateway _source;

  Future<String?> exportSnapshot() async {
    if (!await _source.hasCustomEditedActiveSource()) return null;
    return _source.readLocalActiveSourceIfExists();
  }

  Future<bool> restoreSnapshot({
    required String? sourceText,
    required bool manifestHasSource,
  }) async {
    if (sourceText != null && sourceText.trim().isNotEmpty) {
      await _source.writeLocalActiveSource(sourceText);
      return true;
    }
    if (manifestHasSource) {
      throw Exception('cloud_sync_source_missing');
    }
    return false;
  }
}
