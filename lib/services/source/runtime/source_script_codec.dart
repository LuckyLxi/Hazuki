import 'dart:collection';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:quickjs_engine/quickjs_engine.dart'
    show JSError, QuickJsTaskStoppedError, QuickJsStopReason;
import 'source_host_call_context.dart';
import '../models/source_script_execution.dart';

/// Graph encoding supports cycles and aliasing on ports and native byte mailboxes.
class SourceScriptCodec {
  SourceScriptCodec({
    required this.encodeCallback,
    required this.decodeCallback,
  });
  final int Function(dynamic) encodeCallback;
  final dynamic Function(int) decodeCallback;
  Map<String, dynamic> encode(dynamic value, {bool transferable = true}) {
    final nodes = <dynamic>[];
    final seen = HashMap<Object, int>.identity();
    dynamic visit(dynamic value) {
      if (value == null || value is String || value is bool || value is int) {
        return value;
      }
      if (value is double) {
        return value.isFinite ? value : ['number', value.toString()];
      }
      final previous = seen[value];
      if (previous != null) return ['ref', previous];
      final id = nodes.length;
      seen[value] = id;
      nodes.add(null);
      if (value is Uint8List) {
        nodes[id] = transferable
            ? [
                'bytes',
                TransferableTypedData.fromList([value]),
              ]
            : ['bytes64', base64Encode(value)];
      } else if (value is List) {
        nodes[id] = ['list', value.map(visit).toList()];
      } else if (value is Map) {
        nodes[id] = [
          'map',
          value.entries
              .map((entry) => [visit(entry.key), visit(entry.value)])
              .toList(),
        ];
      } else if (value is SourceScriptStopped) {
        nodes[id] = [
          'stopped',
          value.execution.toMap(),
          value.runtimeId,
          value.nativeToken,
          value.reason,
          value.timedOut,
          value.stack,
        ];
      } else if (value is QuickJsTaskStoppedError) {
        nodes[id] = [
          'nativeStopped',
          value.taskToken,
          value.reason.index,
          value.stack,
        ];
      } else if (value is JSError || value is Error || value is Exception) {
        final error = value is JSError ? value : JSError(value);
        nodes[id] = ['error', error.message, error.stack];
      } else {
        nodes[id] = ['callback', encodeCallback(value)];
      }
      return ['ref', id];
    }

    final root = visit(value);
    return {'root': root, 'nodes': nodes};
  }

  dynamic decode(dynamic encoded) {
    final graph = encoded as Map;
    final nodes = graph['nodes'] as List;
    final decoded = <int, dynamic>{};
    dynamic visit(dynamic value) {
      if (value is! List) return value;
      if (value[0] == 'number') return double.parse(value[1] as String);
      final id = value[1] as int;
      if (decoded.containsKey(id)) return decoded[id];
      final node = nodes[id] as List;
      switch (node[0]) {
        case 'list':
          final result = <dynamic>[];
          decoded[id] = result;
          result.addAll((node[1] as List).map(visit));
          return result;
        case 'map':
          final result = <dynamic, dynamic>{};
          decoded[id] = result;
          for (final entry in node[1] as List) {
            result[visit(entry[0])] = visit(entry[1]);
          }
          return result;
        case 'bytes':
          decoded[id] = (node[1] as TransferableTypedData)
              .materialize()
              .asUint8List();
        case 'bytes64':
          decoded[id] = base64Decode(node[1] as String);
        case 'error':
          decoded[id] = JSError(node[1], node[2]);
        case 'stopped':
          decoded[id] = SourceScriptStopped(
            execution: SourceScriptExecution.fromMap(node[1] as Map),
            runtimeId: node[2] as String,
            nativeToken: node[3] as int,
            reason: node[4] as String,
            timedOut: node[5] as bool,
            stack: node[6] as String,
          );
        case 'nativeStopped':
          decoded[id] = QuickJsTaskStoppedError(
            node[1] as int,
            QuickJsStopReason.values[node[2] as int],
            node[3] as String,
          );
        case 'callback':
          decoded[id] = decodeCallback(node[1] as int);
        default:
          throw StateError('source_script_wire_value_invalid');
      }
      return decoded[id];
    }

    return visit(graph['root']);
  }
}
