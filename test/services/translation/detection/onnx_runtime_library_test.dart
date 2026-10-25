import 'dart:ffi';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/translation/detection/onnx_runtime_library.dart';

void main() {
  test('supported Snapdragon SoCs get the QNN build for their NPU', () {
    final spec = onnxRuntimeLibraryFor(
      'android',
      Abi.androidArm64,
      socModel: 'SM8650',
    )!;
    expect(spec.version, '1.23.2');
    expect(spec.directoryName, '1.23.2-qnn2.37.1-v75');
    expect(spec.license, 'MIT / Qualcomm QNN');
    expect(spec.archiveEntry, 'jni/arm64-v8a/libonnxruntime.so');
    expect(spec.companions.map((file) => file.fileName), [
      'libQnnSystem.so',
      'libQnnHtpPrepare.so',
      'libQnnHtpV75Stub.so',
      'libQnnHtpV75Skel.so',
      qnnHtpLibraryName,
    ]);
    expect(
      spec.downloadBytes,
      spec.entryCompressedBytes +
          spec.companions.fold(0, (sum, f) => sum + f.entryCompressedBytes),
    );
    expect(
      onnxRuntimeLibraryFor(
        'android',
        Abi.androidArm64,
        socModel: 'SM8750',
      )!.companions.map((file) => file.fileName),
      contains('libQnnHtpV79Skel.so'),
    );
  });

  test('other Android devices keep the CPU build', () {
    for (final soc in [null, 'SM8450', 'MT6989']) {
      final spec = onnxRuntimeLibraryFor(
        'android',
        Abi.androidArm64,
        socModel: soc,
      )!;
      expect(spec.variant, isNull, reason: soc);
      expect(spec.directoryName, '1.23.2');
      expect(spec.companions, isEmpty);
      expect(spec.license, 'MIT');
    }
    // 32 位设备即使是骁龙也没有 QNN 版。
    expect(
      onnxRuntimeLibraryFor(
        'android',
        Abi.androidArm,
        socModel: 'SM8650',
      )!.variant,
      isNull,
    );
  });

  test('Windows uses the DirectML build', () {
    final spec = onnxRuntimeLibraryFor('windows', Abi.windowsX64)!;
    expect(spec.version, '1.23.0');
    expect(spec.directoryName, '1.23.0');
    expect(spec.companions.single.fileName, directMlLibraryName);
    expect(onnxRuntimeLibraryFor('linux', Abi.linuxX64), isNull);
  });
}
