enum ReaderFilterColor {
  yellow('yellow'),
  black('black');

  const ReaderFilterColor(this.prefsValue);

  final String prefsValue;
}

ReaderFilterColor readerFilterColorFromRaw(String? raw) {
  return ReaderFilterColor.values.firstWhere(
    (color) => color.prefsValue == raw,
    orElse: () => ReaderFilterColor.yellow,
  );
}
