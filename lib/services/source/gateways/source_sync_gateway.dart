abstract interface class SourceSyncGateway {
  String get activeSourceKey;
  Future<bool> hasCustomEditedActiveSource();
  Future<String?> readLocalActiveSourceIfExists();
  Future<void> writeLocalActiveSource(String content);
  Future<void> reloadFromLocalSourceFiles();
}
