// 插件只提供嵌套 List 形式的张量读写，百万级元素时开销过大；这里直接调用 C API。
// ignore_for_file: implementation_imports
import 'dart:ffi' as ffi;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:onnxruntime_v2/onnxruntime_v2.dart';
import 'package:onnxruntime_v2/src/bindings/onnxruntime_bindings_generated.dart'
    as bg;

/// 由 float32 数据创建输入张量；数据复制到原生内存，随张量 release 一并释放。
OrtValueTensor createFloatTensor(Float32List data, List<int> shape) {
  final api = OrtEnv.instance.ortApiPtr.ref;
  final dataPtr = calloc<ffi.Float>(data.length);
  dataPtr.asTypedList(data.length).setAll(0, data);
  final shapePtr = calloc<ffi.Int64>(shape.length);
  shapePtr.asTypedList(shape.length).setAll(0, shape);
  final infoPtr = calloc<ffi.Pointer<bg.OrtMemoryInfo>>();
  final valuePtr = calloc<ffi.Pointer<bg.OrtValue>>();
  try {
    OrtStatus.checkOrtStatus(
      api.AllocatorGetInfo.asFunction<
        bg.OrtStatusPtr Function(
          ffi.Pointer<bg.OrtAllocator>,
          ffi.Pointer<ffi.Pointer<bg.OrtMemoryInfo>>,
        )
      >()(OrtAllocator.instance.ptr, infoPtr),
    );
    OrtStatus.checkOrtStatus(
      api.CreateTensorWithDataAsOrtValue.asFunction<
        bg.OrtStatusPtr Function(
          ffi.Pointer<bg.OrtMemoryInfo>,
          ffi.Pointer<ffi.Void>,
          int,
          ffi.Pointer<ffi.Int64>,
          int,
          int,
          ffi.Pointer<ffi.Pointer<bg.OrtValue>>,
        )
      >()(
        infoPtr.value,
        dataPtr.cast(),
        data.length * 4,
        shapePtr,
        shape.length,
        bg.ONNXTensorElementDataType.ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT,
        valuePtr,
      ),
    );
    return OrtValueTensor(valuePtr.value, dataPtr.cast());
  } catch (_) {
    calloc.free(dataPtr);
    rethrow;
  } finally {
    calloc.free(shapePtr);
    calloc.free(infoPtr);
    calloc.free(valuePtr);
  }
}

/// 读取 float32 输出张量，返回数据副本与形状。
(Float32List, List<int>) readFloatTensor(OrtValue value) {
  final api = OrtEnv.instance.ortApiPtr.ref;
  final infoPtr = calloc<ffi.Pointer<bg.OrtTensorTypeAndShapeInfo>>();
  final countPtr = calloc<ffi.Size>();
  final dataPtr = calloc<ffi.Pointer<ffi.Void>>();
  try {
    OrtStatus.checkOrtStatus(
      api.GetTensorTypeAndShape.asFunction<
        bg.OrtStatusPtr Function(
          ffi.Pointer<bg.OrtValue>,
          ffi.Pointer<ffi.Pointer<bg.OrtTensorTypeAndShapeInfo>>,
        )
      >()(value.ptr, infoPtr),
    );
    final List<int> shape;
    try {
      OrtStatus.checkOrtStatus(
        api.GetDimensionsCount.asFunction<
          bg.OrtStatusPtr Function(
            ffi.Pointer<bg.OrtTensorTypeAndShapeInfo>,
            ffi.Pointer<ffi.Size>,
          )
        >()(infoPtr.value, countPtr),
      );
      final count = countPtr.value;
      final dims = calloc<ffi.Int64>(count);
      try {
        OrtStatus.checkOrtStatus(
          api.GetDimensions.asFunction<
            bg.OrtStatusPtr Function(
              ffi.Pointer<bg.OrtTensorTypeAndShapeInfo>,
              ffi.Pointer<ffi.Int64>,
              int,
            )
          >()(infoPtr.value, dims, count),
        );
        shape = List.of(dims.asTypedList(count));
      } finally {
        calloc.free(dims);
      }
    } finally {
      api.ReleaseTensorTypeAndShapeInfo.asFunction<
        void Function(ffi.Pointer<bg.OrtTensorTypeAndShapeInfo>)
      >()(infoPtr.value);
    }
    OrtStatus.checkOrtStatus(
      api.GetTensorMutableData.asFunction<
        bg.OrtStatusPtr Function(
          ffi.Pointer<bg.OrtValue>,
          ffi.Pointer<ffi.Pointer<ffi.Void>>,
        )
      >()(value.ptr, dataPtr),
    );
    final length = shape.fold(1, (total, dim) => total * dim);
    final data = Float32List.fromList(
      dataPtr.value.cast<ffi.Float>().asTypedList(length),
    );
    return (data, shape);
  } finally {
    calloc.free(infoPtr);
    calloc.free(countPtr);
    calloc.free(dataPtr);
  }
}
