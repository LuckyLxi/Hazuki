import 'package:flutter/widgets.dart';
import 'package:hazuki/shared/reading/reader_mode.dart';

/// Navigation can select a page, but cannot replace images or change settings.
abstract interface class ReaderNavigationState {
  int get currentPageIndex;
  int get imageCount;
  int get activePointerCount;
  bool get isZoomed;
  bool get pageNavigationLocked;
  ReaderMode get readerMode;
  int get readerSpreadCount;
  int get readerSpreadSize;
  bool get tapToTurnPage;
  bool get volumeButtonTurnPage;
  List<GlobalKey> get itemKeys;
  int normalizeSpreadIndex(int index);
  int spreadStartIndex(int spreadIndex);
  void setCurrentPageIndex(int index);
}
