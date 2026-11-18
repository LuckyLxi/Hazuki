import 'dart:convert';
import 'dart:typed_data';

/// 只保留 ONNX 模型中指定名称的图输出，并删除不再影响这些输出的节点。
///
/// ONNX Runtime 不会裁掉没有下游的节点，CTD 只请求 `blk` 时仍会执行分割与
/// DB 解码头中开销很大的 ConvTranspose。这里直接按 protobuf 线格式改写
/// `ModelProto.graph`，不引入完整的 protobuf 依赖；未使用的权重由运行时清理。
Uint8List pruneOnnxGraphOutputs(Uint8List model, Set<String> keep) {
  final output = BytesBuilder(copy: false);
  _rewriteFields(model, output, (field, wireType, value) {
    if (field != _modelGraphField || wireType != _lengthDelimited) return value;
    return _pruneGraph(value, keep);
  });
  return output.takeBytes();
}

const _modelGraphField = 7;
const _graphNodeField = 1;
const _graphOutputField = 12;
const _nodeInputField = 1;
const _nodeOutputField = 2;
const _lengthDelimited = 2;

Uint8List _pruneGraph(Uint8List graph, Set<String> keep) {
  final nodes = <(List<String>, List<String>)>[];
  _rewriteFields(graph, BytesBuilder(copy: false), (field, wireType, value) {
    if (field == _graphNodeField) nodes.add(_nodeTensors(value));
    return value;
  });
  // 节点按拓扑序排列，自后向前回溯所需张量即可得到保留集合。
  final needed = {...keep};
  final kept = List.filled(nodes.length, false);
  for (var index = nodes.length - 1; index >= 0; index--) {
    final (inputs, outputs) = nodes[index];
    if (!outputs.any(needed.contains)) continue;
    kept[index] = true;
    needed.addAll(inputs);
  }
  var nodeIndex = 0;
  final output = BytesBuilder(copy: false);
  _rewriteFields(graph, output, (field, wireType, value) {
    if (field == _graphNodeField) return kept[nodeIndex++] ? value : null;
    if (field == _graphOutputField) {
      return keep.contains(_stringField(value, 1).firstOrNull) ? value : null;
    }
    return value;
  });
  return output.takeBytes();
}

(List<String>, List<String>) _nodeTensors(Uint8List node) =>
    (_stringField(node, _nodeInputField), _stringField(node, _nodeOutputField));

/// 逐个复制字段；长度定界字段交给 [rewrite] 决定替换内容，返回 null 表示删除。
void _rewriteFields(
  Uint8List bytes,
  BytesBuilder output,
  Uint8List? Function(int field, int wireType, Uint8List value) rewrite,
) {
  var offset = 0;
  while (offset < bytes.length) {
    final start = offset;
    final (tag, afterTag) = _readVarint(bytes, offset);
    offset = afterTag;
    final field = tag >> 3, wireType = tag & 7;
    switch (wireType) {
      case 0:
        offset = _readVarint(bytes, offset).$2;
        output.add(Uint8List.sublistView(bytes, start, offset));
      case 1:
        offset = _checkedEnd(bytes, offset + 8);
        output.add(Uint8List.sublistView(bytes, start, offset));
      case 5:
        offset = _checkedEnd(bytes, offset + 4);
        output.add(Uint8List.sublistView(bytes, start, offset));
      case _lengthDelimited:
        final (length, afterLength) = _readVarint(bytes, offset);
        offset = _checkedEnd(bytes, afterLength + length);
        final value = Uint8List.sublistView(bytes, afterLength, offset);
        final replaced = rewrite(field, wireType, value);
        if (replaced == null) continue;
        if (identical(replaced, value)) {
          output.add(Uint8List.sublistView(bytes, start, offset));
        } else {
          output.add(_varint(tag));
          output.add(_varint(replaced.length));
          output.add(replaced);
        }
      default:
        throw FormatException('Unsupported protobuf wire type $wireType');
    }
  }
}

int _checkedEnd(Uint8List bytes, int end) {
  if (end > bytes.length) {
    throw const FormatException('Truncated protobuf message');
  }
  return end;
}

List<String> _stringField(Uint8List message, int target) {
  final values = <String>[];
  _rewriteFields(message, BytesBuilder(copy: false), (field, wireType, value) {
    if (field == target && wireType == _lengthDelimited) {
      values.add(utf8.decode(value, allowMalformed: true));
    }
    return value;
  });
  return values;
}

(int, int) _readVarint(Uint8List bytes, int offset) {
  var result = 0, shift = 0;
  while (true) {
    if (offset >= bytes.length) {
      throw const FormatException('Truncated protobuf varint');
    }
    final byte = bytes[offset++];
    result |= (byte & 0x7f) << shift;
    if (byte & 0x80 == 0) return (result, offset);
    shift += 7;
  }
}

Uint8List _varint(int value) {
  final bytes = <int>[];
  do {
    var byte = value & 0x7f;
    value >>= 7;
    if (value != 0) byte |= 0x80;
    bytes.add(byte);
  } while (value != 0);
  return Uint8List.fromList(bytes);
}
