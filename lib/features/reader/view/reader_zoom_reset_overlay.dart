import 'package:flutter/material.dart';

class ReaderZoomResetOverlay extends StatelessWidget {
  const ReaderZoomResetOverlay({
    super.key,
    required this.controlsVisible,
    required this.isZoomed,
    required this.onResetZoom,
    required this.label,
  });

  final bool controlsVisible;
  final bool isZoomed;
  final VoidCallback onResetZoom;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      bottom: controlsVisible ? 104 : 24,
      left: 0,
      right: 0,
      child: Center(
        child: IgnorePointer(
          ignoring: !isZoomed,
          child: AnimatedScale(
            scale: isZoomed ? 1.0 : 0.7,
            duration: const Duration(milliseconds: 220),
            curve: isZoomed ? Curves.easeOutBack : Curves.easeInCubic,
            child: AnimatedOpacity(
              opacity: isZoomed ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: GestureDetector(
                onTap: onResetZoom,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.zoom_out_map_rounded,
                        color: Colors.white,
                        size: 15,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
