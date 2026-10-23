enum TranslationDetectorKind { ctd, paddleDb }

/// DB 文字检测后处理参数，取自 PaddleX 官方 `inference.yml`。
class DbPostProcessParams {
  const DbPostProcessParams({
    this.thresh = 0.3,
    this.boxThresh = 0.6,
    this.unclipRatio = 1.5,
    this.maxCandidates = 1000,
  });

  final double thresh;
  final double boxThresh;
  final double unclipRatio;
  final int maxCandidates;
}

class TranslationDetectorModelSpec {
  const TranslationDetectorModelSpec({
    required this.id,
    required this.version,
    required this.kind,
    required this.url,
    required this.downloadBytes,
    required this.sha256,
    required this.license,
    required this.detectionMaxSide,
    this.archiveEntry,
    this.keepOutputs,
    this.db = const DbPostProcessParams(),
  });

  final String id;
  final int version;
  final TranslationDetectorKind kind;
  final String url;
  final int downloadBytes;

  /// 下载文件（CTD 为 ONNX 本体，Paddle 为 tar 包）的 SHA-256。
  final String sha256;
  final String license;

  /// 送入检测前切片图像缩放到的最长边。
  final int detectionMaxSide;

  /// tar 包内要提取的模型文件名；为 null 时下载文件即模型。
  final String? archiveEntry;

  /// 安装时只保留这些图输出并裁掉其余分支；为 null 时保持原模型。
  final Set<String>? keepOutputs;
  final DbPostProcessParams db;
}

const kTranslationDetectorModels = [
  TranslationDetectorModelSpec(
    id: 'comic_text_detector',
    version: 1,
    kind: TranslationDetectorKind.ctd,
    url:
        'https://github.com/zyddnys/manga-image-translator/releases/download/beta-0.2.1/comictextdetector.pt.onnx',
    downloadBytes: 94669756,
    sha256: '1a86ace74961413cbd650002e7bb4dcec4980ffa21b2f19b86933372071d718f',
    license: 'GPL-3.0',
    detectionMaxSide: 1024,
    // 只用 YOLO 文字块输出；分割与 DB 头的 ConvTranspose 在 CPU 上极慢。
    keepOutputs: {'blk'},
  ),
  TranslationDetectorModelSpec(
    id: 'pp_ocrv5_mobile_det',
    version: 1,
    kind: TranslationDetectorKind.paddleDb,
    url:
        'https://paddle-model-ecology.bj.bcebos.com/paddlex/official_inference_model/paddle3.0.0/PP-OCRv5_mobile_det_onnx_infer.tar',
    downloadBytes: 4843520,
    sha256: '781056046c9ed77a15c94681605db6a0f62317c2e9cce6931c71da2478d4bc30',
    license: 'Apache-2.0',
    detectionMaxSide: 960,
    archiveEntry: 'inference.onnx',
  ),
  TranslationDetectorModelSpec(
    id: 'pp_ocrv5_server_det',
    version: 1,
    kind: TranslationDetectorKind.paddleDb,
    url:
        'https://paddle-model-ecology.bj.bcebos.com/paddlex/official_inference_model/paddle3.0.0/PP-OCRv5_server_det_onnx_infer.tar',
    downloadBytes: 88135680,
    sha256: 'cd28389ed2c11dfe02d6a9847ec95ca6153a51bf38bc1c4e2521c1f548188f58',
    license: 'Apache-2.0',
    detectionMaxSide: 960,
    archiveEntry: 'inference.onnx',
  ),
];

TranslationDetectorModelSpec? translationDetectorModelSpec(String? id) {
  for (final spec in kTranslationDetectorModels) {
    if (spec.id == id) return spec;
  }
  return null;
}
