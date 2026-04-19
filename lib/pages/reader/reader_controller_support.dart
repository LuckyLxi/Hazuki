import 'package:flutter/material.dart';

typedef ReaderContextGetter = BuildContext Function();
typedef ReaderIsMounted = bool Function();
typedef ReaderStateUpdate = void Function(VoidCallback update);
typedef ReaderLogEvent =
    void Function(String title, {String level, String source, Object? content});
typedef ReaderLogPayloadBuilder =
    Map<String, dynamic> Function([Map<String, dynamic>? extra]);
typedef ReaderVisiblePageLogger =
    void Function({required int index, required String trigger});
typedef ReaderResetZoom = void Function({String reason});
