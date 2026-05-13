import 'package:flutter/material.dart';

typedef ReaderCommentsWidgetBuilder =
    Widget Function({
      required String comicId,
      String? subId,
      ScrollController? scrollController,
      Future<void> Function()? onRequestTabFullscreen,
    });
