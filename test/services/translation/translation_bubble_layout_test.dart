import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/translation/imaging/bubble_snapper.dart';
import 'package:hazuki/services/translation/models/translation_models.dart';
import 'package:image/image.dart' as img;

void main() {
  test('detector passages cannot snap to a nearby narrow strip', () {
    final image = img.Image(width: 400, height: 400, numChannels: 4);
    img.fill(image, color: img.ColorRgb8(70, 70, 70));
    img.fillRect(
      image,
      x1: 240,
      y1: 100,
      x2: 350,
      y2: 280,
      color: img.ColorRgb8(255, 210, 255),
    );
    img.fillRect(
      image,
      x1: 20,
      y1: 120,
      x2: 380,
      y2: 144,
      color: img.ColorRgb8(255, 255, 255),
    );
    img.fillRect(
      image,
      x1: 270,
      y1: 130,
      x2: 320,
      y2: 240,
      color: img.ColorRgb8(0, 0, 0),
    );
    img.fillRect(
      image,
      x1: 90,
      y1: 128,
      x2: 130,
      y2: 137,
      color: img.ColorRgb8(0, 0, 0),
    );
    final rgba = image.getBytes(order: img.ChannelOrder.rgba);
    TranslationRegion region(Rect box, TranslationRegionKind kind) =>
        TranslationRegion(
          id: 'passage',
          box: box,
          kind: kind,
          sourceText: '先生の手をつないでる',
          translatedText: '现在正牵着老师的手',
          sourceVertical: true,
          boxSource: TranslationBoxSource.detector,
        );
    // 多列文字框不够窄，不能依靠单列长宽比来避免误判。
    const passage = Rect.fromLTRB(250 / 400, 110 / 400, 340 / 400, 250 / 400);
    for (final kind in [
      TranslationRegionKind.bubble,
      TranslationRegionKind.caption,
    ]) {
      final result = const BubbleSnapper().snap(rgba, 400, 400, [
        region(passage, kind),
      ]).single;
      expect(result.sourceVertical, isTrue);
      expect(result.kind, isNot(TranslationRegionKind.caption));
      expect(result.layoutBox!.height * 400, greaterThan(80));
      expect(result.layoutBox!.center.dx, closeTo(passage.center.dx, .04));
    }
    final caption = const BubbleSnapper().snap(rgba, 400, 400, [
      region(
        const Rect.fromLTRB(88 / 400, 126 / 400, 132 / 400, 139 / 400),
        TranslationRegionKind.bubble,
      ),
    ]).single;
    expect(caption.kind, TranslationRegionKind.caption);
    expect(caption.sourceVertical, isFalse);
    expect(caption.layoutBox!.top * 400, greaterThanOrEqualTo(120));
    expect(caption.layoutBox!.bottom * 400, lessThanOrEqualTo(145));
  });

  test(
    'rejects a surrounding street component whose bounds enclose a balloon',
    () {
      final image = img.Image(width: 400, height: 400, numChannels: 4);
      img.fill(image, color: img.ColorRgb8(30, 30, 30));
      img.fillRect(
        image,
        x1: 20,
        y1: 20,
        x2: 380,
        y2: 380,
        color: img.ColorRgb8(150, 165, 195),
      );
      img.fillRect(
        image,
        x1: 250,
        y1: 100,
        x2: 350,
        y2: 280,
        color: img.ColorRgb8(255, 210, 255),
      );
      for (var y = 140; y < 250; y += 25) {
        img.fillRect(
          image,
          x1: 270,
          y1: y,
          x2: 330,
          y2: y + 9,
          color: img.ColorRgb8(0, 0, 0),
        );
      }
      final result = const BubbleSnapper().snap(
        image.getBytes(order: img.ChannelOrder.rgba),
        400,
        400,
        [
          const TranslationRegion(
            id: 'street',
            box: Rect.fromLTRB(260 / 400, 138 / 400, 340 / 400, 252 / 400),
            boxSource: TranslationBoxSource.detector,
            kind: TranslationRegionKind.bubble,
            sourceText: '老師感興趣的話',
            translatedText: '先生が興味あるなら',
            sourceVertical: true,
          ),
        ],
      ).single;
      expect(result.backgroundColor, const Color(0xffffd2ff));
      expect(result.layoutBox!.left, greaterThan(250 / 400));
      expect(result.layoutBox!.right, lessThan(351 / 400));
      for (final patch in result.textPatches!) {
        expect(patch.box.left, greaterThanOrEqualTo(250 / 400));
        expect(patch.box.right, lessThanOrEqualTo(351 / 400));
        expect(patch.box.top, greaterThanOrEqualTo(100 / 400));
        expect(patch.box.bottom, lessThanOrEqualTo(281 / 400));
      }
    },
  );

  for (final kind in [
    TranslationRegionKind.bubble,
    TranslationRegionKind.caption,
  ]) {
    test(
      'keeps a tall CJK passage vertical despite a wrong kind or flag: $kind',
      () {
        final image = img.Image(width: 400, height: 500, numChannels: 4);
        img.fill(image, color: img.ColorRgb8(60, 60, 60));
        img.fillRect(
          image,
          x1: 280,
          y1: 30,
          x2: 370,
          y2: 450,
          color: img.ColorRgb8(255, 255, 255),
        );
        // 横向白色装饰线会穿过这条竖列，不能把局部留白当作整段横幅。
        img.fillRect(
          image,
          x1: 20,
          y1: 240,
          x2: 380,
          y2: 264,
          color: img.ColorRgb8(255, 255, 255),
        );
        for (var y = 70; y < 430; y += 40) {
          img.fillRect(
            image,
            x1: 315,
            y1: y,
            x2: 335,
            y2: y + 24,
            color: img.ColorRgb8(0, 0, 0),
          );
        }
        final result = const BubbleSnapper().snap(
          image.getBytes(order: img.ChannelOrder.rgba),
          400,
          500,
          [
            TranslationRegion(
              id: 'vertical',
              box: const Rect.fromLTRB(
                310 / 400,
                65 / 500,
                340 / 400,
                435 / 500,
              ),
              kind: kind,
              sourceText: 'お嫁さんになって',
              translatedText: '成为我的新娘吧',
              sourceVertical: false,
            ),
          ],
        ).single;
        expect(result.kind, isNot(TranslationRegionKind.caption));
        expect(result.sourceVertical, isTrue);
        if (result.layoutBox case final layout?) {
          expect(layout.height * 500, greaterThan(layout.width * 400 * 2));
        }
      },
    );
  }
  for (final kind in [
    TranslationRegionKind.bubble,
    TranslationRegionKind.narration,
    TranslationRegionKind.caption,
  ]) {
    test(
      'finds the caption instead of adjacent white artwork with kind=$kind',
      () {
        final image = img.Image(width: 400, height: 300, numChannels: 4);
        img.fill(image, color: img.ColorRgb8(70, 70, 70));
        img.fillRect(
          image,
          x1: 110,
          y1: 40,
          x2: 300,
          y2: 280,
          color: img.ColorRgb8(255, 255, 255),
        );
        for (var x = 20; x < 380; x++) {
          final shade = (1 - ((x - 200).abs() / 180)).clamp(0.0, 1.0);
          final red = (215 + math.min(1, shade * 2) * 40).round();
          final green = (230 + math.min(1, shade * 2) * 25).round();
          final blue = (240 + math.min(1, shade * 2) * 15).round();
          img.fillRect(
            image,
            x1: x,
            y1: 80,
            x2: x,
            y2: 104,
            color: img.ColorRgb8(red, green, blue),
          );
        }
        img.fillRect(
          image,
          x1: 185,
          y1: 87,
          x2: 235,
          y2: 97,
          color: img.ColorRgb8(10, 10, 10),
        );
        final result = const BubbleSnapper().snap(
          image.getBytes(order: img.ChannelOrder.rgba),
          400,
          300,
          [
            TranslationRegion(
              id: 'huh',
              box: const Rect.fromLTRB(
                150 / 400,
                84 / 300,
                340 / 400,
                275 / 300,
              ),
              kind: kind,
              sourceText: '欸…！？',
              translatedText: 'Huh...!?',
              sourceVertical: true,
            ),
          ],
        ).single;
        expect(result.kind, TranslationRegionKind.caption);
        expect(result.sourceVertical, isFalse);
        final layout = result.layoutBox!;
        expect(layout.left, lessThan(60 / 400));
        expect(layout.right, greaterThan(350 / 400));
        expect(layout.top, greaterThanOrEqualTo(80 / 300));
        expect(layout.bottom, lessThanOrEqualTo(105 / 300));
        expect(layout.height * 300, greaterThan(18));
        expect(result.textPatches, isNotEmpty);
        expect(
          result.textPatches!.any(
            (patch) => patch.box.contains(const Offset(210 / 400, 92 / 300)),
          ),
          isTrue,
        );
        for (final patch in result.textPatches!) {
          expect(patch.box.top, greaterThanOrEqualTo(80 / 300));
          expect(patch.box.bottom, lessThanOrEqualTo(105 / 300));
        }
      },
    );
  }

  test('repairs dense outlined text without filling an occluding object', () {
    final image = img.Image(width: 240, height: 260, numChannels: 4);
    img.fill(image, color: img.ColorRgb8(70, 70, 70));
    img.fillRect(
      image,
      x1: 40,
      y1: 40,
      x2: 200,
      y2: 220,
      color: img.ColorRgb8(255, 210, 255),
    );
    img.fillRect(
      image,
      x1: 140,
      y1: 95,
      x2: 175,
      y2: 165,
      color: img.ColorRgb8(255, 255, 255),
    );
    img.fillRect(
      image,
      x1: 143,
      y1: 98,
      x2: 172,
      y2: 162,
      color: img.ColorRgb8(0, 0, 0),
    );
    img.fillRect(
      image,
      x1: 170,
      y1: 110,
      x2: 220,
      y2: 150,
      color: img.ColorRgb8(70, 70, 70),
    );
    final result = const BubbleSnapper().snap(
      image.getBytes(order: img.ChannelOrder.rgba),
      240,
      260,
      [
        const TranslationRegion(
          id: 'dense',
          box: Rect.fromLTRB(143 / 240, 98 / 260, 167 / 240, 163 / 260),
          kind: TranslationRegionKind.bubble,
          sourceText: '挑戰書',
          translatedText: '挑戦状',
          sourceVertical: true,
        ),
      ],
    ).single;
    expect(result.layoutBox, isNotNull);
    expect(
      result.textPatches!.any(
        (patch) => patch.box.contains(const Offset(160 / 240, 130 / 260)),
      ),
      isTrue,
    );
    expect(
      result.textPatches!.any(
        (patch) => patch.box.contains(const Offset(185 / 240, 130 / 260)),
      ),
      isFalse,
    );
  });

  test(
    'short caption text finds the surrounding wide banner and stays horizontal',
    () {
      final image = img.Image(width: 300, height: 160, numChannels: 4);
      img.fill(image, color: img.ColorRgb8(70, 70, 70));
      img.fillRect(
        image,
        x1: 25,
        y1: 60,
        x2: 275,
        y2: 95,
        color: img.ColorRgb8(225, 240, 245),
      );
      img.fillRect(
        image,
        x1: 145,
        y1: 68,
        x2: 160,
        y2: 85,
        color: img.ColorRgb8(0, 0, 0),
      );
      final result = const BubbleSnapper().snap(
        image.getBytes(order: img.ChannelOrder.rgba),
        300,
        160,
        [
          const TranslationRegion(
            id: 'caption',
            box: Rect.fromLTRB(145 / 300, 68 / 160, 161 / 300, 86 / 160),
            kind: TranslationRegionKind.caption,
            sourceText: '欸！？',
            translatedText: 'えっ！？',
            sourceVertical: true,
          ),
        ],
      ).single;
      expect(result.kind, TranslationRegionKind.caption);
      expect(result.sourceVertical, isFalse);
      expect(result.layoutBox!.width * 300, greaterThan(220));
      expect(result.layoutBox!.height * 160, inInclusiveRange(25, 36));
    },
  );

  test(
    'keeps both lobes and leaves an untranslated lower passage untouched',
    () {
      final image = img.Image(width: 200, height: 300, numChannels: 4);
      img.fill(image, color: img.ColorRgb8(70, 70, 70));
      for (final y in [95, 205]) {
        img.fillCircle(
          image,
          x: 100,
          y: y,
          radius: 70,
          color: img.ColorRgb8(170, 235, 245),
        );
      }
      for (final y in [55, 165]) {
        img.fillRect(
          image,
          x1: 90,
          y1: y,
          x2: 110,
          y2: y + 79,
          color: img.ColorRgb8(0, 0, 0),
        );
      }
      const upper = TranslationRegion(
        id: 'upper',
        box: Rect.fromLTRB(.45, 55 / 300, .555, 135 / 300),
        kind: TranslationRegionKind.bubble,
        sourceText: '您自己一個人單獨看哦！',
        translatedText: '一人で見てね！',
        sourceVertical: true,
      );
      const lower = TranslationRegion(
        id: 'lower',
        box: Rect.fromLTRB(.45, 165 / 300, .555, 245 / 300),
        kind: TranslationRegionKind.bubble,
        sourceText: '現在不可以看啦！',
        translatedText: '今は見ちゃだめ！',
        sourceVertical: true,
      );
      final rgba = image.getBytes(order: img.ChannelOrder.rgba);
      final both = const BubbleSnapper().snap(rgba, 200, 300, [upper, lower]);
      expect(both[0].layoutBox, isNotNull);
      expect(both[1].layoutBox, isNotNull);
      expect(both[0].layoutBox!.overlaps(both[1].layoutBox!), isFalse);
      expect(
        both[0].textPatches!.any(
          (patch) => patch.box.contains(lower.box.center),
        ),
        isFalse,
      );
      expect(
        both[1].textPatches!.any(
          (patch) => patch.box.contains(lower.box.center),
        ),
        isTrue,
      );
      final onlyUpper = const BubbleSnapper()
          .snap(rgba, 200, 300, [upper], textBoxes: [lower.box])
          .single;
      expect(
        onlyUpper.textPatches!.any(
          (patch) => patch.box.contains(lower.box.center),
        ),
        isFalse,
      );
      expect(onlyUpper.layoutBox!.bottom, lessThan(lower.box.top));
    },
  );

  test('erases the other source columns in the same passage', () {
    final image = img.Image(width: 240, height: 240, numChannels: 4);
    img.fill(image, color: img.ColorRgb8(70, 70, 70));
    img.fillCircle(
      image,
      x: 120,
      y: 120,
      radius: 95,
      color: img.ColorRgb8(255, 210, 255),
    );
    for (final x in [85, 120]) {
      img.fillRect(
        image,
        x1: x,
        y1: 65,
        x2: x + 18,
        y2: 175,
        color: img.ColorRgb8(0, 0, 0),
      );
    }
    const source = TranslationRegion(
      id: 'columns',
      box: Rect.fromLTRB(.5, 65 / 240, 139 / 240, 176 / 240),
      kind: TranslationRegionKind.bubble,
      sourceText: '雖然說是挑戰書',
      translatedText: '挑戦状と言っても…',
      sourceVertical: true,
    );
    final result = const BubbleSnapper().snap(
      image.getBytes(order: img.ChannelOrder.rgba),
      240,
      240,
      [source],
    ).single;
    expect(
      result.textPatches!.any(
        (patch) => patch.box.contains(const Offset(94 / 240, .5)),
      ),
      isTrue,
    );
    expect(
      result.textPatches!.any(
        (patch) => patch.box.contains(const Offset(130 / 240, .5)),
      ),
      isTrue,
    );
  });
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
