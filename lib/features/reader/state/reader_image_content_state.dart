import 'package:hazuki/shared/reading/reader_mode.dart';

/// The image pipeline can apply a chapter or its load error, while settings and
/// independent page selection stay with their own controllers.
abstract interface class ReaderImageContentState {
  List<String> get images;
  int get currentPageIndex;
  ReaderMode get readerMode;
  int get readerSpreadSize;
  int spreadStartIndex(int spreadIndex);
  List<int> spreadImageIndices(int spreadIndex);

  void applyImages(List<String> nextImages);
  void markLoadImagesFailed(String message);
}
