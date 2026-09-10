class DownloadGroup {
  const DownloadGroup({
    required this.id,
    required this.name,
    required this.createdAtMs,
    this.sortOrder = 0,
  });

  static const String defaultGroupId = 'default';
  static const String defaultGroupName = 'Default';

  final String id;
  final String name;
  final int createdAtMs;
  final int sortOrder;

  bool get isDefault => id == defaultGroupId;
}
