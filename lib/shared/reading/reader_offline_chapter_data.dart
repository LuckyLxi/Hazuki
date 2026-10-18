class ReaderOfflineChapterData {
  const ReaderOfflineChapterData({
    required this.epId,
    required this.title,
    required this.index,
    required this.images,
    this.groupId,
    this.groupTitle,
  });

  final String epId;
  final String? groupId;
  final String? groupTitle;
  final String title;
  final int index;
  final List<String> images;
}
