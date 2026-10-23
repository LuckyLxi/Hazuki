import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:dio/dio.dart';

import 'translation_detector_models.dart';

/// 送入检测模型的切片图像，RGBA 像素按行排列。
class DetectionImage {
  const DetectionImage({
    required this.rgba,
    required this.width,
    required this.height,
  });

  final Uint8List rgba;
  final int width;
  final int height;
}

abstract interface class TranslationTextDetector {
  /// 返回以切片为参照、归一化到 0–1 的轴对齐文字框。
  Future<List<Rect>> detect(
    DetectionImage image,
    TranslationDetectorModelSpec spec,
    File model, {
    CancelToken? cancelToken,
  });

  /// 释放模型会话与工作 isolate；下次检测时重新加载。
  Future<void> release();
}
