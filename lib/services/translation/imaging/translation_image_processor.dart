import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;

import '../manga_translation_provider.dart';
import '../detection/translation_text_detector.dart';
import '../models/translation_models.dart';

class TranslationImageSlice {
  const TranslationImageSlice({
    required this.payload,
    required this.top,
    required this.bottom,
    required this.ownedTop,
    required this.ownedBottom,
    this.detection,
  });

  final TranslationImagePayload payload;
  final double top;
  final double bottom;
  final double ownedTop;
  final double ownedBottom;

  /// 与 [payload] 同一裁剪区域的检测输入；未启用本地检测时为 null。
  final DetectionImage? detection;

  /// 把切片内的归一化坐标换算为整页坐标。
  ui.Rect mapRect(ui.Rect box) => ui.Rect.fromLTRB(
    box.left,
    top + box.top * (bottom - top),
    box.right,
    top + box.bottom * (bottom - top),
  );

  List<TranslationRegion> mapRegions(List<TranslationRegion> regions) {
    final output = <TranslationRegion>[];
    for (final region in regions) {
      final box = mapRect(region.box);
      final center = box.center.dy;
      if (center < ownedTop || center >= ownedBottom && ownedBottom < 1) {
        continue;
      }
      output.add(
        TranslationRegion(
          id: region.id,
          box: box,
          kind: region.kind,
          sourceText: region.sourceText,
          translatedText: region.translatedText,
          sourceVertical: region.sourceVertical,
          backgroundColor: region.backgroundColor,
          boxSource: region.boxSource,
          sourceBoxes: region.sourceBoxes.map(mapRect).toList(),
          sourceIds: region.sourceIds,
          layoutBox: region.layoutBox == null
              ? null
              : mapRect(region.layoutBox!),
          textPatches: region.textPatches
              ?.map(
                (patch) =>
                    TranslationTextPatch(mapRect(patch.box), patch.color),
              )
              .toList(),
        ),
      );
    }
    return output;
  }
}

class PreparedTranslationImage {
  const PreparedTranslationImage({
    required this.slices,
    required this.snapRgba,
    required this.snapWidth,
    required this.snapHeight,
  });

  final List<TranslationImageSlice> slices;
  final Uint8List snapRgba;
  final int snapWidth;
  final int snapHeight;
}

class TranslationImageProcessor {
  const TranslationImageProcessor();

  /// 检测器可能把连体气泡的上下两段合成一个框。只在明显的大段留白处分段，
  /// 普通竖排的字距和横排的行距不作为分段依据。
  static List<ui.Rect> splitDetectedPassages(
    DetectionImage image,
    List<ui.Rect> boxes,
  ) {
    final output = <ui.Rect>[];
    for (final box in boxes) {
      final left = (box.left * image.width).floor().clamp(0, image.width - 1);
      final right = (box.right * image.width).ceil().clamp(
        left + 1,
        image.width,
      );
      final top = (box.top * image.height).floor().clamp(0, image.height - 1);
      final bottom = (box.bottom * image.height).ceil().clamp(
        top + 1,
        image.height,
      );
      final width = right - left, height = bottom - top;
      if (width < 6 || height < width * 1.5) {
        output.add(box);
        continue;
      }
      final rows = List<bool>.filled(height, false);
      var bright = 0;
      for (var y = top; y < bottom; y++) {
        var ink = 0;
        for (var x = left; x < right; x++) {
          final offset = (y * image.width + x) * 4;
          final r = image.rgba[offset],
              g = image.rgba[offset + 1],
              b = image.rgba[offset + 2];
          if (r > 160 && g > 160 && b > 160) bright++;
          if (r < 120 && g < 120 && b < 120) ink++;
        }
        rows[y - top] = ink >= math.max(2, width * 0.025);
      }
      if (bright < width * height * 0.2) {
        output.add(box);
        continue;
      }
      var start = 0, cursor = 0;
      final parts = <ui.Rect>[];
      while (cursor < height) {
        if (rows[cursor]) {
          cursor++;
          continue;
        }
        final gap = cursor;
        while (cursor < height && !rows[cursor]) {
          cursor++;
        }
        if (gap - start >= width * 0.6 &&
            height - cursor >= width * 0.6 &&
            cursor - gap >= width * 0.6) {
          parts.add(
            ui.Rect.fromLTRB(
              box.left,
              (top + start) / image.height,
              box.right,
              (top + gap) / image.height,
            ),
          );
          start = cursor;
        }
      }
      if (parts.isEmpty) {
        output.add(box);
        continue;
      }
      parts.add(
        ui.Rect.fromLTRB(
          box.left,
          (top + start) / image.height,
          box.right,
          box.bottom,
        ),
      );
      output.addAll(parts);
    }
    return output;
  }

  Future<PreparedTranslationImage> prepare(
    Uint8List bytes, {
    int? detectionMaxSide,
  }) async {
    // dart:ui 解码由引擎异步完成；纯 Dart 的像素计算交给工作 isolate。
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      final image = frame.image;
      try {
        final data = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        final rgba = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        final width = image.width;
        final height = image.height;
        return await Isolate.run(
          () => prepareRgba(
            rgba,
            width,
            height,
            detectionMaxSide: detectionMaxSide,
          ),
        );
      } finally {
        image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }

  static PreparedTranslationImage prepareRgba(
    Uint8List rgba,
    int width,
    int height, {
    int? detectionMaxSide,
  }) {
    final original = img.Image.fromBytes(
      width: width,
      height: height,
      bytes: rgba.buffer,
      bytesOffset: rgba.offsetInBytes,
      numChannels: 4,
    );
    final sliceHeight = height / width > 2
        ? math.max(1, (width * 1.6).round())
        : height;
    final step = math.max(1, (sliceHeight * 0.9).round());
    final ranges = <(int, int)>[];
    for (var top = 0; top < height; top += step) {
      final bottom = math.min(height, top + sliceHeight);
      ranges.add((top, bottom));
      if (bottom == height) break;
    }
    final slices = <TranslationImageSlice>[];
    for (var index = 0; index < ranges.length; index++) {
      final (top, bottom) = ranges[index];
      final cropped = img.copyCrop(
        original,
        x: 0,
        y: top,
        width: width,
        height: bottom - top,
      );
      final resized = _resize(cropped, 1568);
      final detection = detectionMaxSide == null
          ? null
          : _resize(cropped, detectionMaxSide);
      slices.add(
        TranslationImageSlice(
          payload: TranslationImagePayload(
            jpegBytes: img.encodeJpg(resized, quality: 85),
            width: resized.width,
            height: resized.height,
          ),
          top: top / height,
          bottom: bottom / height,
          ownedTop: index == 0 ? 0 : (top + ranges[index - 1].$2) / 2 / height,
          ownedBottom: index == ranges.length - 1
              ? 1
              : (bottom + ranges[index + 1].$1) / 2 / height,
          detection: detection == null
              ? null
              : DetectionImage(
                  rgba: detection.getBytes(order: img.ChannelOrder.rgba),
                  width: detection.width,
                  height: detection.height,
                ),
        ),
      );
    }
    // 吸附按区域读取原图，保留长图中的字边和气泡轮廓。
    return PreparedTranslationImage(
      slices: slices,
      snapRgba: rgba,
      snapWidth: width,
      snapHeight: height,
    );
  }

  /// 在发给 AI 的图上画出检测框和编号，让模型按画面上的标注认领框，
  /// 不必自行把坐标换算回画面位置（模型这一步常把相邻框张冠李戴）。
  static TranslationImagePayload annotateBoxes(
    TranslationImagePayload payload,
    Map<String, ui.Rect> boxes,
  ) {
    // 标注只是辅助认领，解码失败时退回原图，不让翻译因此失败。
    img.Image? image;
    try {
      image = img.decodeJpg(payload.jpegBytes);
    } catch (_) {}
    if (image == null) return payload;
    final outline = img.ColorRgb8(255, 0, 64);
    final text = img.ColorRgb8(255, 255, 255);
    final font = img.arial24;
    for (final box in boxes.values) {
      img.drawRect(
        image,
        x1: (box.left * image.width).round(),
        y1: (box.top * image.height).round(),
        x2: (box.right * image.width).round(),
        y2: (box.bottom * image.height).round(),
        color: outline,
        thickness: 2,
      );
    }
    // 编号后画，避免被其他框的描边压住。
    for (final MapEntry(key: id, value: box) in boxes.entries) {
      final labelWidth =
          id.codeUnits.fold<int>(
            0,
            (sum, code) => sum + (font.characters[code]?.xAdvance ?? 0),
          ) +
          6;
      final labelHeight = font.lineHeight + 2;
      final left = math.max(
        0,
        math.min((box.left * image.width).round(), image.width - labelWidth),
      );
      // 优先放在框外上方，不遮挡框内文字；贴近顶边时放到框内。
      var top = (box.top * image.height).round() - labelHeight;
      if (top < 0) top = (box.top * image.height).round();
      top = math.max(0, math.min(top, image.height - labelHeight));
      img.fillRect(
        image,
        x1: left,
        y1: top,
        x2: left + labelWidth - 1,
        y2: top + labelHeight - 1,
        color: outline,
      );
      img.drawString(
        image,
        id,
        font: font,
        x: left + 3,
        y: top + 1,
        color: text,
      );
    }
    return TranslationImagePayload(
      jpegBytes: img.encodeJpg(image, quality: 85),
      width: image.width,
      height: image.height,
    );
  }

  static img.Image _resize(img.Image image, int maximum) {
    final longest = math.max(image.width, image.height);
    if (longest <= maximum) return image;
    final ratio = maximum / longest;
    return img.copyResize(
      image,
      width: math.max(1, (image.width * ratio).round()),
      height: math.max(1, (image.height * ratio).round()),
      interpolation: img.Interpolation.linear,
    );
  }
}
