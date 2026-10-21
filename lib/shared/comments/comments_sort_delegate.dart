import 'package:flutter/foundation.dart';
import 'package:hazuki/services/source/plugins/source_sort_options.dart';

abstract interface class CommentsSortDelegate implements Listenable {
  String get sourceKey;
  SourceCommentSortOptions get sortOptions;
  String get selectedOrder;
  Future<void> setOrder(String order);
}
