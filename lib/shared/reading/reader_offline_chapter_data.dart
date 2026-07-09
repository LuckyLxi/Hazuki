class ReaderOfflineChapterData {
  const ReaderOfflineChapterData({
    required this.epId,
    required this.title,
    required this.index,
    required this.images,
  });

  final String epId;
  final String title;
  final int index;
  final List<String> images;
}
