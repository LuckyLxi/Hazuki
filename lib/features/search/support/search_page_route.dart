import 'package:flutter/widgets.dart';
import 'package:hazuki/shared/navigation/snapshotting_page_route.dart';

Route<T> buildSearchEntryPageRoute<T>({required WidgetBuilder builder}) =>
    buildSnapshottingPageRoute<T>(builder: builder);
