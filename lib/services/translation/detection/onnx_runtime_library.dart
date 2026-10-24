import 'dart:ffi';
import 'dart:io';

/// 本地检测使用的 ONNX Runtime 动态库；按需下载，不随安装包分发。
class OnnxRuntimeLibrarySpec {
  const OnnxRuntimeLibrarySpec({
    required this.sources,
    required this.archiveBytes,
    required this.archiveEntry,
    required this.fileName,
    required this.sha256,
    required this.entryCompressedBytes,
  });

  static const version = '1.23.2';
  static const license = 'MIT';

  /// 依次尝试的下载地址，内容完全相同；只有网络失败才换下一个。
  final List<String> sources;

  /// 发布包（zip / aar）的总字节数，用于计算分段下载的区间。
  final int archiveBytes;

  /// 发布包内动态库的路径。
  final String archiveEntry;
  final String fileName;

  /// 解压后动态库的 SHA-256。
  final String sha256;

  /// 动态库在发布包中的压缩大小，即分段下载时的实际流量。
  final int entryCompressedBytes;
}

const _androidSources = [
  'https://repo1.maven.org/maven2/com/microsoft/onnxruntime/onnxruntime-android/1.23.2/onnxruntime-android-1.23.2.aar',
  // 国内网络无法访问官方仓库时使用阿里云镜像。
  'https://maven.aliyun.com/repository/public/com/microsoft/onnxruntime/onnxruntime-android/1.23.2/onnxruntime-android-1.23.2.aar',
];
const _androidArchiveBytes = 30241654;

OnnxRuntimeLibrarySpec _android(String abi, String sha256, int compressed) =>
    OnnxRuntimeLibrarySpec(
      sources: _androidSources,
      archiveBytes: _androidArchiveBytes,
      archiveEntry: 'jni/$abi/libonnxruntime.so',
      fileName: 'libonnxruntime.so',
      sha256: sha256,
      entryCompressedBytes: compressed,
    );

/// 当前平台对应的运行库；不支持本地检测的平台返回 null。
OnnxRuntimeLibrarySpec? onnxRuntimeLibraryForCurrentPlatform() =>
    onnxRuntimeLibraryFor(Platform.operatingSystem, Abi.current());

OnnxRuntimeLibrarySpec? onnxRuntimeLibraryFor(String os, Abi abi) => switch ((
  os,
  abi,
)) {
  ('windows', Abi.windowsX64) => const OnnxRuntimeLibrarySpec(
    sources: [
      'https://github.com/microsoft/onnxruntime/releases/download/v1.23.2/onnxruntime-win-x64-1.23.2.zip',
    ],
    archiveBytes: 78127794,
    archiveEntry: 'onnxruntime-win-x64-1.23.2/lib/onnxruntime.dll',
    fileName: 'onnxruntime.dll',
    sha256: 'dec964ab1ee36cc9b0ae247d13b376627992fc57dec0454354017ab8fd84f1ea',
    entryCompressedBytes: 5250009,
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
