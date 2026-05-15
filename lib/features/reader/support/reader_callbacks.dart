import 'package:flutter/material.dart';

typedef ReaderCommentsWidgetBuilder =
    Widget Function({
      required String comicId,
      String? subId,
      required String sourceKey,
      ScrollController? scrollController,
      Future<void> Function()? onRequestTabFullscreen,
    });
