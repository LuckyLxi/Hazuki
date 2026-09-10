import 'package:flutter/widgets.dart';

class DiscoverBackToTopNotification extends Notification {
  const DiscoverBackToTopNotification({
    required this.visible,
    required this.onPressed,
  });

  final bool visible;
  final VoidCallback onPressed;
}
