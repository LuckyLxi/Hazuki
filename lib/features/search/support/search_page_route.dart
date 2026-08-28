import 'package:flutter/cupertino.dart';

Route<T> buildSearchEntryPageRoute<T>({required WidgetBuilder builder}) {
  return CupertinoPageRoute<T>(builder: builder, allowSnapshotting: false);
}
