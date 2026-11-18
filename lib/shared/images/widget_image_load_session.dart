import 'dart:typed_data';
import '../../services/source/models/source_task.dart';

import '../../services/source/gateways/source_image_gateways.dart';
import 'widget_image_memory.dart';

/// Owns request identity while widgets retain their presentation state.
class WidgetImageLoadSession {
  int _generation = 0;

  SourceTaskCancellation? _cancellation;
  void invalidate([
    SourceTaskStopReason reason = SourceTaskStopReason.superseded,
  ]) {
    _generation++;
    _cancellation?.cancel(reason);
    _cancellation = null;
  }

  WidgetImageLoadRequest begin({
    required String url,
    required SourceImageGateway gateway,
    required String sourceKey,
    required bool peekGatewayMemory,
    required bool keepInGatewayMemory,
    required bool keepInWidgetMemory,
  }) {
    invalidate();
    final cancellation = _cancellation = SourceTaskCancellation();
    return WidgetImageLoadRequest._(
      this,
      _generation,
      cancellation,
      url,
      gateway,
      sourceKey,
      peekGatewayMemory,
      keepInGatewayMemory,
      keepInWidgetMemory,
    );
  }
}

class WidgetImageLoadRequest {
  WidgetImageLoadRequest._(
    this._session,
    this._generation,
    this._cancellation,
    this.url,
    this.gateway,
    this.sourceKey,
    this._peekGatewayMemory,
    this._keepInGatewayMemory,
    this._keepInWidgetMemory,
  );

  final WidgetImageLoadSession _session;
  final int _generation;
  final SourceTaskCancellation _cancellation;
  final String url;
  final SourceImageGateway gateway;
  final String sourceKey;
  final bool _peekGatewayMemory;
  final bool _keepInGatewayMemory;
  final bool _keepInWidgetMemory;

  bool matches({
    required String url,
    required SourceImageGateway gateway,
    required String sourceKey,
  }) =>
      _generation == _session._generation &&
      this.url == url &&
      identical(this.gateway, gateway) &&
      this.sourceKey == sourceKey;

  Uint8List? peek() {
    final bytes =
        takeHazukiWidgetImageMemory(url, sourceKey: sourceKey) ??
        (_peekGatewayMemory
            ? gateway.peekImageBytesFromMemory(url, sourceKey: sourceKey)
            : null);
    if (bytes != null && _peekGatewayMemory) retain(bytes);
    return bytes;
  }

  Future<Uint8List> download() => gateway.downloadImageBytes(
    url,
    sourceKey: sourceKey,
    keepInMemory: _keepInGatewayMemory,
    taskOrigin: SourceTaskOrigin(
      ownerId: createSourceTaskId(),
      groupId: createSourceTaskId(),
      requestSequence: _generation,
      cancellation: _cancellation,
    ),
  );

  void retain(Uint8List bytes) {
    if (_keepInWidgetMemory && _generation == _session._generation) {
      putHazukiWidgetImageMemory(url, bytes, sourceKey: sourceKey);
    }
  }
}
