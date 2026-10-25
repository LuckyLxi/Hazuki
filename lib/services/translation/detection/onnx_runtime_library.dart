import 'dart:ffi';
import 'dart:io';

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
  });

  static const license = 'MIT';

  final String version;

  /// 与主库放在同一目录的依赖库，例如 DirectML 版运行库所需的 DirectML.dll。
  final List<OnnxRuntimeLibraryFile> companions;

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

/// 当前平台对应的运行库；不支持本地检测的平台返回 null。
OnnxRuntimeLibrarySpec? onnxRuntimeLibraryForCurrentPlatform() =>
    onnxRuntimeLibraryFor(Platform.operatingSystem, Abi.current());

OnnxRuntimeLibrarySpec? onnxRuntimeLibraryFor(String os, Abi abi) => switch ((
  os,
  abi,
)) {
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
