/// Zoom can track pointers and gestures, but cannot change settings or images.
abstract interface class ReaderZoomState {
  bool get pinchToZoom;
  bool get isZoomed;
  bool get zoomInteracting;
  int get activePointerCount;

  void pointerDown();
  void pointerUp();
  void setZoomed(bool zoomed);
  void beginZoomInteraction();
  void finishZoomInteraction({required bool zoomed});
  void resetZoom({bool resetPointers = true});
}
