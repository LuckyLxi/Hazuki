import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// 发布包（zip / aar / nupkg）中按需提取的单个动态库。
class OnnxRuntimeLibraryFile {
  const OnnxRuntimeLibraryFile({
    required this.sources,
    required this.archiveBytes,
    required this.archiveEntry,
    required this.fileName,
    required this.sha256,
    required this.entryCompressedBytes,
  });

  /// 依次尝试的下载地址，内容完全相同；只有网络失败才换下一个。
  final List<String> sources;

  /// 发布包的总字节数，用于计算分段下载的区间。
  final int archiveBytes;

  /// 发布包内动态库的路径。
  final String archiveEntry;
  final String fileName;

  /// 解压后动态库的 SHA-256。
  final String sha256;

  /// 动态库在发布包中的压缩大小，即分段下载时的实际流量。
  final int entryCompressedBytes;
}

/// 本地检测使用的 ONNX Runtime 动态库；按需下载，不随安装包分发。
class OnnxRuntimeLibrarySpec extends OnnxRuntimeLibraryFile {
  const OnnxRuntimeLibrarySpec({
    required this.version,
    required super.sources,
    required super.archiveBytes,
    required super.archiveEntry,
    required super.fileName,
    required super.sha256,
    required super.entryCompressedBytes,
    this.companions = const [],
    this.variant,
    this.license = 'MIT',
  });

  /// ONNX Runtime 版本，加载校验时与运行库自报的版本比对。
  final String version;

  /// 同一 ORT 版本的不同构建（如骁龙 NPU 版）；不同构建分目录存放，切换时重新下载。
  final String? variant;
  final String license;

  /// 与主库放在同一目录的依赖库，例如 DirectML 版运行库所需的 DirectML.dll。
  final List<OnnxRuntimeLibraryFile> companions;

  /// 运行库安装目录名。
  String get directoryName => variant == null ? version : '$version-$variant';

  /// 主库与依赖库合计的实际下载流量。
  int get downloadBytes => companions.fold(
    entryCompressedBytes,
    (total, file) => total + file.entryCompressedBytes,
  );
}

/// DirectML 版运行库依赖的库文件名；运行库目录中存在该文件时启用 GPU 推理。
const directMlLibraryName = 'DirectML.dll';

const _androidVersion = '1.23.2';
const _androidSources = [
  'https://repo1.maven.org/maven2/com/microsoft/onnxruntime/onnxruntime-android/1.23.2/onnxruntime-android-1.23.2.aar',
  // 国内网络无法访问官方仓库时使用阿里云镜像。
  'https://maven.aliyun.com/repository/public/com/microsoft/onnxruntime/onnxruntime-android/1.23.2/onnxruntime-android-1.23.2.aar',
];
const _androidArchiveBytes = 30241654;

OnnxRuntimeLibrarySpec _android(String abi, String sha256, int compressed) =>
    OnnxRuntimeLibrarySpec(
      version: _androidVersion,
      sources: _androidSources,
      archiveBytes: _androidArchiveBytes,
      archiveEntry: 'jni/$abi/libonnxruntime.so',
      fileName: 'libonnxruntime.so',
      sha256: sha256,
      entryCompressedBytes: compressed,
    );

/// 骁龙 NPU 版运行库的后端库文件名；运行库目录中存在该文件时启用 NPU 推理。
const qnnHtpLibraryName = 'libQnnHtp.so';

/// 已知 Hexagon NPU 架构的骁龙型号（ro.soc.model）。只收录确认支持 FP16 的型号，
/// 其余骁龙与其他芯片保持 CPU 版运行库。目前仅 SM8650 经过真机验证。
const _snapdragonHtpArchs = {
  'SM8550': 73, // 8 Gen 2
  'SM8635': 73, // 8s Gen 3
  'SM8650': 75, // 8 Gen 3
  'SM8750': 79, // 8 Elite
};

const _qnnOrtSources = [
  'https://repo1.maven.org/maven2/com/microsoft/onnxruntime/onnxruntime-android-qnn/1.23.2/onnxruntime-android-qnn-1.23.2.aar',
  'https://maven.aliyun.com/repository/public/com/microsoft/onnxruntime/onnxruntime-android-qnn/1.23.2/onnxruntime-android-qnn-1.23.2.aar',
];
// 与 onnxruntime-android-qnn 1.23.2 依赖的 QNN SDK 版本一致。
const _qnnRuntimeVersion = '2.37.1';
const _qnnRuntimeSources = [
  'https://repo1.maven.org/maven2/com/qualcomm/qti/qnn-runtime/2.37.1/qnn-runtime-2.37.1.aar',
  'https://maven.aliyun.com/repository/public/com/qualcomm/qti/qnn-runtime/2.37.1/qnn-runtime-2.37.1.aar',
];
const _qnnRuntimeArchiveBytes = 52461791;

OnnxRuntimeLibraryFile _qnnFile(String name, String sha256, int compressed) =>
    OnnxRuntimeLibraryFile(
      sources: _qnnRuntimeSources,
      archiveBytes: _qnnRuntimeArchiveBytes,
      archiveEntry: 'jni/arm64-v8a/$name',
      fileName: name,
      sha256: sha256,
      entryCompressedBytes: compressed,
    );

// 各 NPU 架构的 Stub（CPU 侧）与 Skel（NPU 侧）库：(sha256, 压缩大小)。
const _qnnHtpArchFiles = {
  73: (
    stub: (
      '283c330e5f09b681840fadd8ea77e2cf192c3f5bb0eddebd60f9ec261d93ebb1',
      241132,
    ),
    skel: (
      '89383862a7bd5ac697f45028160ff102576f47a5392c31e26a911abea858e9a2',
      3294483,
    ),
  ),
  75: (
    stub: (
      'c80b51e4214f2e1f1878e4a5234675600a4f07437c473dd2b545306ea630b860',
      241131,
    ),
    skel: (
      '7b05c9233ce5475909381f856a9641d8912b51448f5ed7c061eaf3610ce62e30',
      3311555,
    ),
  ),
  79: (
    stub: (
      '39cea00ad69f6b813c303cb483a48798bc04c7c44c01f3e75bb851c1bc0ffc98',
      241131,
    ),
    skel: (
      'e88b019fe24383f6871ea47e3d3afe6c2121dc62146164e9b14444aa419d9098',
      3385544,
    ),
  ),
};

/// 骁龙 NPU 版：QNN 版 ORT（同样包含 CPU 推理）加上 HTP 后端与对应架构的库。
OnnxRuntimeLibrarySpec _snapdragon(int arch) {
  final files = _qnnHtpArchFiles[arch]!;
  return OnnxRuntimeLibrarySpec(
    version: _androidVersion,
    variant: 'qnn$_qnnRuntimeVersion-v$arch',
    license: 'MIT / Qualcomm QNN',
    sources: _qnnOrtSources,
    archiveBytes: 7382023,
    archiveEntry: 'jni/arm64-v8a/libonnxruntime.so',
    fileName: 'libonnxruntime.so',
    sha256: '894a89523b620c7e3231c3fbdbf186d4e80e10fb12a86f98fc2a6913413b148c',
    entryCompressedBytes: 7104936,
    companions: [
      _qnnFile(
        'libQnnSystem.so',
        '025e33d6445c63ee1559ad0c30cd899f4629e52ceec7ca66ee70392ba77021a1',
        929203,
      ),
      // 首次加载模型时在设备上编译 NPU 图所需，编译结果会缓存。
      _qnnFile(
        'libQnnHtpPrepare.so',
        'e6d88f594ae98880e03aabc069a190c2a2b9813de2a66e95eeb520463fa2b541',
        29565504,
      ),
      _qnnFile('libQnnHtpV${arch}Stub.so', files.stub.$1, files.stub.$2),
      _qnnFile('libQnnHtpV${arch}Skel.so', files.skel.$1, files.skel.$2),
      _qnnFile(
        qnnHtpLibraryName,
        '703f1ac08c518a92caa41793e388b9b0c0570ab8d690782713e5e3386fb97227',
        926595,
      ),
    ],
  );
}

/// 当前平台对应的运行库；不支持本地检测的平台返回 null。
OnnxRuntimeLibrarySpec? onnxRuntimeLibraryForCurrentPlatform() =>
    onnxRuntimeLibraryFor(
      Platform.operatingSystem,
      Abi.current(),
      socModel: Platform.isAndroid ? _androidSocModel() : null,
    );

/// 读取骁龙芯片型号；非高通芯片或读取失败时返回 null。
String? _androidSocModel() {
  try {
    final get = DynamicLibrary.process()
        .lookupFunction<
          Int32 Function(Pointer<Utf8>, Pointer<Utf8>),
          int Function(Pointer<Utf8>, Pointer<Utf8>)
        >('__system_property_get');
    // 系统属性值最长 92 字节（PROP_VALUE_MAX）。
    final value = calloc<Uint8>(92).cast<Utf8>();
    try {
      String read(String name) {
        final key = name.toNativeUtf8();
        try {
          get(key, value);
          return value.toDartString();
        } finally {
          calloc.free(key);
        }
      }

      if (read('ro.soc.manufacturer') != 'QTI') return null;
      return read('ro.soc.model');
    } finally {
      calloc.free(value);
    }
  } catch (_) {
    return null;
  }
}

OnnxRuntimeLibrarySpec? onnxRuntimeLibraryFor(
  String os,
  Abi abi, {
  String? socModel,
}) => switch ((os, abi)) {
  ('android', Abi.androidArm64) when _snapdragonHtpArchs[socModel] != null =>
    _snapdragon(_snapdragonHtpArchs[socModel]!),
  // Windows 使用 DirectML 版（官方只发布到 1.23.0），GPU 不可用时同一个库仍可走 CPU。
  ('windows', Abi.windowsX64) => const OnnxRuntimeLibrarySpec(
    version: '1.23.0',
    sources: [
      'https://api.nuget.org/v3-flatcontainer/microsoft.ml.onnxruntime.directml/1.23.0/microsoft.ml.onnxruntime.directml.1.23.0.nupkg',
    ],
    archiveBytes: 12746067,
    archiveEntry: 'runtimes/win-x64/native/onnxruntime.dll',
    fileName: 'onnxruntime.dll',
    sha256: 'f5131591edac6b0a8090d0e329040a49319d7a689cb5b465235fbf7030fa8027',
    entryCompressedBytes: 6121610,
    companions: [
      // 系统自带的 DirectML 版本过旧，使用 ONNX Runtime 1.23 配套的可再发行版本。
      OnnxRuntimeLibraryFile(
        sources: [
          'https://api.nuget.org/v3-flatcontainer/microsoft.ai.directml/1.15.4/microsoft.ai.directml.1.15.4.nupkg',
        ],
        archiveBytes: 202292617,
        archiveEntry: 'bin/x64-win/DirectML.dll',
        fileName: directMlLibraryName,
        sha256:
            '9c9e6d822561c6c41b90e6994b3e8857cf1d66dbfb1e0c4c799c7c89b4e92da1',
        entryCompressedBytes: 9332741,
      ),
    ],
  ),
  ('android', Abi.androidArm64) => _android(
    'arm64-v8a',
    'e40f09d07dc53726b8bfbf48a7907673b8f86718a057655a62790a39874a7302',
    6974611,
  ),
  ('android', Abi.androidArm) => _android(
    'armeabi-v7a',
    '57048b8d54896d16355ee367bfc129c5925468ae503b681b8d0cd49ceefa468e',
    6331824,
  ),
  ('android', Abi.androidX64) => _android(
    'x86_64',
    '972c17c056eaae946a415d9efdd8018b729639974df075e495f0092441478fb7',
    8283107,
  ),
  ('android', Abi.androidIA32) => _android(
    'x86',
    '213d91ebb0cfd511c18c0057c69145de0abc6bdc9c63429bf04dcdeaf3fd861a',
    8293098,
  ),
  _ => null,
};
