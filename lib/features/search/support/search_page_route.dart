import 'package:flutter/material.dart';

Route<T> buildSearchEntryPageRoute<T>({required WidgetBuilder builder}) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    allowSnapshotting: false,
    transitionsBuilder: _buildSearchEntryTransition,
  );
}

Widget _buildSearchEntryTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final offset = Tween<Offset>(
    begin: const Offset(1, 0),
    end: Offset.zero,
  ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation);
  return SlideTransition(
    position: offset,
    child: RepaintBoundary(child: child),
  );
}
