import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/translation/detection/onnx_model_pruner.dart';

List<int> _varint(int value) {
  final bytes = <int>[];
  do {
    var byte = value & 0x7f;
    value >>= 7;
    if (value != 0) byte |= 0x80;
    bytes.add(byte);
  } while (value != 0);
  return bytes;
}

List<int> _field(int number, List<int> bytes) => [
  ..._varint(number << 3 | 2),
  ..._varint(bytes.length),
  ...bytes,
];

List<int> _string(int number, String value) =>
    _field(number, utf8.encode(value));

List<int> _node(String name, List<String> inputs, List<String> outputs) =>
    _field(1, [
      for (final input in inputs) ..._string(1, input),
      for (final output in outputs) ..._string(2, output),
      ..._string(3, name),
    ]);

List<int> _output(String name) => _field(12, _string(1, name));

Uint8List _model(List<int> graph) => Uint8List.fromList([
  0x08, 0x07, // ir_version
  ..._field(7, graph),
  ..._field(8, [0x08, 0x0b]), // opset_import
]);

void main() {
  final docString = _string(10, 'x' * 300);
  final initializer = _field(5, List.filled(200, 1));
  final input = _field(11, _string(1, 'images'));

  test('keeps only nodes that feed the requested outputs', () {
    final model = _model([
      ..._node('stem', ['images', 'w'], ['features']),
      ..._node('block', ['features'], ['blk']),
      ..._node('decoder', ['features'], ['up']),
      ..._node('segment', ['up'], ['seg']),
      ..._string(2, 'graph'),
      ...initializer,
      ...docString,
      ...input,
      ..._output('blk'),
      ..._output('seg'),
    ]);
    final pruned = pruneOnnxGraphOutputs(model, {'blk'});
    expect(
      pruned,
      _model([
        ..._node('stem', ['images', 'w'], ['features']),
        ..._node('block', ['features'], ['blk']),
        ..._string(2, 'graph'),
        ...initializer,
        ...docString,
        ...input,
        ..._output('blk'),
      ]),
    );
  });

  test('leaves a model unchanged when every output is kept', () {
    final model = _model([
      ..._node('block', ['images'], ['blk']),
      ...input,
      ..._output('blk'),
    ]);
    expect(pruneOnnxGraphOutputs(model, {'blk'}), model);
  });

  test('rejects truncated data', () {
    expect(
      () => pruneOnnxGraphOutputs(Uint8List.fromList([0x3a, 0x10, 0x01]), {}),
      throwsFormatException,
    );
  });
}
