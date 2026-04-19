enum ReaderMode {
  topToBottom,
  rightToLeft;

  String get prefsValue => switch (this) {
    ReaderMode.topToBottom => 'top_to_bottom',
    ReaderMode.rightToLeft => 'right_to_left',
  };
}

ReaderMode readerModeFromRaw(String? raw) {
  return switch (raw) {
    'right_to_left' => ReaderMode.rightToLeft,
    _ => ReaderMode.topToBottom,
  };
}
