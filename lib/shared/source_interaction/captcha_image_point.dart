import 'package:flutter/painting.dart';

/// Maps logical widget coordinates to unscaled image pixels, excluding padding.
Offset? captchaImagePoint(Offset local, Size canvas, Size image) {
  if (image.isEmpty || canvas.isEmpty) return null;
  final fitted = applyBoxFit(BoxFit.contain, image, canvas);
  final destination = Alignment.center.inscribe(
    fitted.destination,
    Offset.zero & canvas,
  );
  if (!destination.contains(local)) return null;
  return Offset(
    (local.dx - destination.left) * image.width / destination.width,
    (local.dy - destination.top) * image.height / destination.height,
  );
}
