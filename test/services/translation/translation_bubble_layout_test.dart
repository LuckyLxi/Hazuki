import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/translation/imaging/bubble_snapper.dart';
import 'package:hazuki/services/translation/models/translation_models.dart';
import 'package:image/image.dart' as img;

void main() {
  const snapper = BubbleSnapper();
  TranslationRegion snap(
    img.Image image,
    Rect box, {
    TranslationRegionKind kind = TranslationRegionKind.bubble,
  }) => snapper.snap(
    image.getBytes(order: img.ChannelOrder.rgba),
    image.width,
    image.height,
    [
      TranslationRegion(
        id: 'r0',
        box: box,
        kind: kind,
        sourceText: '原文',
        translatedText: 'The translation should use the whole balloon.',
        sourceVertical: true,
      ),
    ],
  ).single;

  for (final dark in [false, true]) {
    test(
      'uses a wide balloon around narrow ${dark ? 'white' : 'black'} text',
      () {
        final image = img.Image(width: 240, height: 240, numChannels: 4);
        img.fill(image, color: img.ColorRgb8(90, 90, 90));
        final background = dark
            ? img.ColorRgb8(0, 0, 0)
            : img.ColorRgb8(160, 235, 245);
        img.fillCircle(image, x: 120, y: 120, radius: 95, color: background);
        img.fillRect(
          image,
          x1: 109,
          y1: 67,
          x2: 130,
          y2: 172,
          color: img.ColorRgb8(255, 255, 255),
        );
        if (!dark) {
          img.fillRect(
            image,
            x1: 112,
            y1: 70,
            x2: 127,
            y2: 169,
            color: img.ColorRgb8(0, 0, 0),
          );
        }
        const source = Rect.fromLTRB(112 / 240, 70 / 240, 128 / 240, 170 / 240);
        final result = snap(image, source);
        expect(result.box, source);
        final layout = result.layoutBox!;
        expect(layout.width, greaterThan(source.width * 6));
        expect(
          layout.width * layout.height,
          greaterThan(source.width * source.height * 3),
        );
        expect(
          result.backgroundColor,
          dark ? const Color(0xff000000) : const Color(0xffa0ebf5),
        );
        final erase = result.textPatches!.map((patch) => patch.box);
        expect(erase.any((rect) => rect.contains(source.center)), isTrue);
        expect(
          erase.any(
            (rect) => rect.contains(const Offset(110 / 240, 100 / 240)),
          ),
          isTrue,
        );
        expect(
          erase.any((rect) => rect.contains(const Offset(50 / 240, 120 / 240))),
          isFalse,
        );
        for (final rect in erase) {
          expect(rect.left, greaterThan(25 / 240));
          expect(rect.right, lessThan(215 / 240));
        }
      },
    );
  }

  test('keeps a slanted caption horizontal and repairs only its letters', () {
    final image = img.Image(width: 300, height: 150, numChannels: 4);
    img.fill(image, color: img.ColorRgb8(90, 90, 90));
    final bar = img.ColorRgb8(225, 240, 245);
    for (var y = 60; y < 90; y++) {
      final shift = (90 - y) ~/ 3;
      img.fillRect(
        image,
        x1: 25 + shift,
        y1: y,
        x2: 265 + shift,
        y2: y,
        color: bar,
      );
    }
    img.fillRect(
      image,
      x1: 100,
      y1: 70,
      x2: 199,
      y2: 79,
      color: img.ColorRgb8(0, 0, 0),
    );
    const source = Rect.fromLTRB(100 / 300, 70 / 150, 200 / 300, 80 / 150);
    final result = snap(image, source, kind: TranslationRegionKind.narration);
    final layout = result.layoutBox!;
    expect(layout.width * 300, greaterThan(200));
    expect(layout.height * 150, lessThan(30));
    expect(layout.width * 300 / (layout.height * 150), greaterThan(7));
    expect(
      result.textPatches!.any((patch) => patch.box.contains(source.center)),
      isTrue,
    );
    expect(
      result.textPatches!.any(
        (patch) => patch.box.contains(const Offset(30 / 300, 75 / 150)),
      ),
      isFalse,
    );
  });

  test('does not use an open page background as a balloon', () {
    final image = img.Image(width: 240, height: 240, numChannels: 4);
    img.fill(image, color: img.ColorRgb8(255, 255, 255));
    img.fillRect(
      image,
      x1: 112,
      y1: 70,
      x2: 127,
      y2: 169,
      color: img.ColorRgb8(0, 0, 0),
    );
    final result = snap(
      image,
      const Rect.fromLTRB(112 / 240, 70 / 240, 128 / 240, 170 / 240),
    );
    expect(result.layoutBox, isNull);
    expect(result.textPatches, isNull);
  });

  test('repairs outlined letters using the surrounding gradient', () {
    final image = img.Image(width: 240, height: 240, numChannels: 4);
    img.fill(image, color: img.ColorRgb8(80, 80, 80));
    for (var y = 0; y < 240; y++) {
      for (var x = 0; x < 240; x++) {
        if ((x - 120) * (x - 120) + (y - 120) * (y - 120) <= 95 * 95) {
          image.setPixelRgba(x, y, 100 + y ~/ 3, 170 + y ~/ 4, 255, 255);
        }
      }
    }
    for (final y in [70, 105, 140]) {
      img.fillRect(
        image,
        x1: 108,
        y1: y - 3,
        x2: 132,
        y2: y + 23,
        color: img.ColorRgb8(255, 255, 255),
      );
      img.fillRect(
        image,
        x1: 112,
        y1: y,
        x2: 128,
        y2: y + 20,
        color: img.ColorRgb8(0, 0, 0),
      );
    }
    final result = snap(
      image,
      const Rect.fromLTRB(112 / 240, 70 / 240, 129 / 240, 161 / 240),
    );
    expect(result.layoutBox, isNotNull);
    final patches = result.textPatches!;
    for (final y in [80, 115, 150]) {
      final patch = patches.firstWhere(
        (patch) => patch.box.contains(Offset(120 / 240, y / 240)),
      );
      expect(patch.color.r * 255, closeTo(100 + y ~/ 3, 12));
      expect(patch.color.g * 255, closeTo(170 + y ~/ 4, 12));
      expect(patch.color.b * 255, closeTo(255, 4));
    }
    expect(patches.first.color, isNot(patches.last.color));
    expect(
      patches.any(
        (patch) => patch.box.contains(const Offset(50 / 240, 120 / 240)),
      ),
      isFalse,
    );
  });

  test('does not mistake a white balloon border for its pink interior', () {
    final image = img.Image(width: 240, height: 240, numChannels: 4);
    img.fill(image, color: img.ColorRgb8(80, 80, 80));
    img.fillCircle(
      image,
      x: 120,
      y: 120,
      radius: 95,
      color: img.ColorRgb8(255, 255, 255),
    );
    img.fillCircle(
      image,
      x: 120,
      y: 120,
      radius: 82,
      color: img.ColorRgb8(255, 210, 255),
    );
    img.fillRect(
      image,
      x1: 110,
      y1: 65,
      x2: 130,
      y2: 175,
      color: img.ColorRgb8(0, 0, 0),
    );
    final result = snap(
      image,
      const Rect.fromLTRB(110 / 240, 65 / 240, 131 / 240, 176 / 240),
    );
    expect(result.backgroundColor, const Color(0xffffd2ff));
    expect(result.layoutBox!.width, greaterThan(0.4));
    expect(result.textPatches!.every((patch) => patch.color.g < 0.9), isTrue);
  });
}
