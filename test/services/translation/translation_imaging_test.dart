import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/translation/imaging/bubble_snapper.dart';
import 'package:hazuki/services/translation/imaging/translation_image_processor.dart';
import 'package:hazuki/services/translation/detection/translation_text_detector.dart';
import 'package:hazuki/services/translation/models/translation_models.dart';
import 'package:image/image.dart' as img;

TranslationRegion _region(
  Rect box, {
  TranslationRegionKind kind = TranslationRegionKind.bubble,
}) => TranslationRegion(
  id: 'r0',
  box: box,
  kind: kind,
  sourceText: 'Hello',
  translatedText: '你好',
  sourceVertical: false,
);

void main() {
  test(
    'splits separate passages inside one detector block, keeping normal glyph gaps',
    () {
      final image = img.Image(width: 160, height: 300, numChannels: 4);
      img.fill(image, color: img.ColorRgb8(180, 235, 245));
      for (final range in [(30, 110), (200, 260)]) {
        img.fillRect(
          image,
          x1: 65,
          y1: range.$1,
          x2: 95,
          y2: range.$2,
          color: img.ColorRgb8(0, 0, 0),
        );
      }
      const box = Rect.fromLTRB(65 / 160, 30 / 300, 96 / 160, 261 / 300);
      final parts = TranslationImageProcessor.splitDetectedPassages(
        DetectionImage(
          rgba: image.getBytes(order: img.ChannelOrder.rgba),
          width: 160,
          height: 300,
        ),
        [box],
      );
      expect(parts, hasLength(2));
      expect(parts[0].bottom, lessThan(parts[1].top));
      expect(parts[0].contains(const Offset(.5, .2)), isTrue);
      expect(parts[1].contains(const Offset(.5, .8)), isTrue);
      final normal = img.Image(width: 160, height: 300, numChannels: 4);
      img.fill(normal, color: img.ColorRgb8(180, 235, 245));
      for (var y = 30; y < 260; y += 26) {
        img.fillRect(
          normal,
          x1: 65,
          y1: y,
          x2: 95,
          y2: y + 19,
          color: img.ColorRgb8(0, 0, 0),
        );
      }
      expect(
        TranslationImageProcessor.splitDetectedPassages(
          DetectionImage(
            rgba: normal.getBytes(order: img.ChannelOrder.rgba),
            width: 160,
            height: 300,
          ),
          [box],
        ),
        [box],
      );
    },
  );
  TestWidgetsFlutterBinding.ensureInitialized();
  const snapper = BubbleSnapper();

  img.Image bubble() {
    final image = img.Image(width: 200, height: 200, numChannels: 4);
    img.fill(image, color: img.ColorRgba8(80, 80, 80, 255));
    for (var y = 0; y < 200; y++) {
      for (var x = 0; x < 200; x++) {
        if ((x - 100) * (x - 100) / (65 * 65) +
                (y - 100) * (y - 100) / (50 * 50) <=
            1) {
          image.setPixelRgba(x, y, 255, 255, 255, 255);
        }
      }
    }
    img.fillRect(
      image,
      x1: 90,
      y1: 85,
      x2: 95,
      y2: 110,
      color: img.ColorRgba8(0, 0, 0, 255),
    );
    img.fillRect(
      image,
      x1: 105,
      y1: 90,
      x2: 110,
      y2: 115,
      color: img.ColorRgba8(0, 0, 0, 255),
    );
    return image;
  }

  test(
    'snaps white elliptical bubbles and tolerates a 20 percent box shift',
    () {
      final image = bubble();
      final bytes = image.getBytes(order: img.ChannelOrder.rgba);
      for (final box in [
        const Rect.fromLTRB(0.28, 0.32, 0.72, 0.68),
        const Rect.fromLTRB(0.368, 0.32, 0.808, 0.68),
      ]) {
        final result = snapper.snap(bytes, 200, 200, [_region(box)]).single;
        expect(result.box, box);
        final layout = result.layoutBox!;
        expect(layout.center.dx, closeTo(0.5, 0.02));
        expect(layout.center.dy, closeTo(0.5, 0.02));
        expect(layout.width, greaterThan(0.4));
        for (final point in [layout.topLeft, layout.bottomRight]) {
          expect(
            (point.dx * 200 - 100) * (point.dx * 200 - 100) / (65 * 65) +
                (point.dy * 200 - 100) * (point.dy * 200 - 100) / (50 * 50),
            lessThan(1),
          );
        }
        expect(result.backgroundColor, const Color(0xffffffff));
      }
    },
  );

  test('does not merge touching bubbles into one snapped box', () {
    // 两个部分重叠的白色圆形气泡，填充时连成一片。
    final image = img.Image(width: 200, height: 120, numChannels: 4);
    img.fill(image, color: img.ColorRgba8(80, 80, 80, 255));
    for (final x in [60, 110]) {
      img.fillCircle(
        image,
        x: x,
        y: 60,
        radius: 40,
        color: img.ColorRgba8(255, 255, 255, 255),
      );
    }
    final bytes = image.getBytes(order: img.ChannelOrder.rgba);
    const left = Rect.fromLTRB(38 / 200, 20 / 120, 83 / 200, 100 / 120);
    const right = Rect.fromLTRB(88 / 200, 20 / 120, 133 / 200, 100 / 120);
    final single = snapper.snap(bytes, 200, 120, [_region(left)]).single;
    // 没有其他文字信息时会连成整片（对照）。
    expect(single.layoutBox!.right, greaterThan(right.center.dx));
    final both = snapper.snap(bytes, 200, 120, [_region(left), _region(right)]);
    expect(both[0].box, left);
    expect(both[1].box, right);
    expect(both[0].layoutBox, isNotNull);
    expect(both[1].layoutBox, isNotNull);
    expect(both[0].layoutBox!.overlaps(both[1].layoutBox!), isFalse);
    final guarded = snapper
        .snap(bytes, 200, 120, [_region(left)], textBoxes: [right])
        .single;
    expect(guarded.box, left);
    expect(guarded.layoutBox!.right, lessThan(right.left));
  });

  test('keeps AI box on a flat page and samples SFX without snapping', () {
    final flat = img.Image(width: 100, height: 100, numChannels: 4);
    img.fill(flat, color: img.ColorRgba8(240, 230, 220, 255));
    const box = Rect.fromLTRB(0.2, 0.2, 0.7, 0.7);
    for (final kind in TranslationRegionKind.values) {
      final result = snapper.snap(
        flat.getBytes(order: img.ChannelOrder.rgba),
        100,
        100,
        [_region(box, kind: kind)],
      ).single;
      expect(result.box, box);
      expect(result.backgroundColor, const Color(0xfff0e6dc));
    }
    final image = bubble();
    expect(
      snapper
          .snap(image.getBytes(order: img.ChannelOrder.rgba), 200, 200, [
            _region(box, kind: TranslationRegionKind.sfx),
          ])
          .single
          .box,
      box,
    );
  });

  test(
    'slices tall pages, encodes JPEG, and gives adjoining ownership intervals',
    () {
      final image = img.Image(width: 100, height: 500, numChannels: 4);
      final prepared = TranslationImageProcessor.prepareRgba(
        image.getBytes(order: img.ChannelOrder.rgba),
        100,
        500,
      );
      expect(prepared.slices, hasLength(4));
      expect(prepared.slices.first.top, 0);
      expect(prepared.slices.last.bottom, 1);
      for (var index = 0; index < prepared.slices.length; index++) {
        final slice = prepared.slices[index];
        expect(img.decodeJpg(slice.payload.jpegBytes), isNotNull);
        if (index + 1 < prepared.slices.length) {
          expect(slice.ownedBottom, prepared.slices[index + 1].ownedTop);
          expect(slice.bottom, greaterThan(prepared.slices[index + 1].top));
        }
      }
      final first = prepared.slices.first;
      final second = prepared.slices[1];
      const globalBox = Rect.fromLTRB(0.2, 0.29, 0.8, 0.31);
      TranslationRegion local(TranslationImageSlice slice) => _region(
        Rect.fromLTRB(
          globalBox.left,
          (globalBox.top - slice.top) / (slice.bottom - slice.top),
          globalBox.right,
          (globalBox.bottom - slice.top) / (slice.bottom - slice.top),
        ),
      );
      final mapped = [
        ...first.mapRegions([local(first)]),
        ...second.mapRegions([local(second)]),
      ];
      expect(mapped, hasLength(1));
      expect(mapped.single.box.top, closeTo(globalBox.top, 0.000001));
      expect(mapped.single.box.bottom, closeTo(globalBox.bottom, 0.000001));
    },
  );

  test(
    'limits payload dimensions and keeps original pixels for local analysis',
    () {
      final image = img.Image(width: 1800, height: 1200, numChannels: 4);
      final prepared = TranslationImageProcessor.prepareRgba(
        image.getBytes(order: img.ChannelOrder.rgba),
        image.width,
        image.height,
      );
      expect(prepared.slices, hasLength(1));
      expect(prepared.slices.single.payload.width, 1568);
      expect(prepared.slices.single.payload.height, lessThanOrEqualTo(1568));
      expect(prepared.snapWidth, image.width);
      expect(prepared.snapHeight, image.height);
      expect(
        prepared.snapRgba.length,
        prepared.snapWidth * prepared.snapHeight * 4,
      );
    },
  );

  test(
    'decodes an actual image and processes it in a worker isolate',
    () async {
      final prepared = await const TranslationImageProcessor().prepare(
        img.encodePng(bubble()),
      );
      expect(prepared.slices.single.payload.width, 200);
      expect(prepared.snapHeight, 200);
    },
  );
}
