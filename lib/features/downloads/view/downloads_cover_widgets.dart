import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:hazuki/services/manga_download_service.dart';
import 'package:hazuki/widgets/widgets.dart';

class DownloadedComicCover extends StatelessWidget {
  const DownloadedComicCover({
    super.key,
    required this.comic,
    this.heroTag,
    this.onTap,
    this.width = 84,
    this.height = 118,
    this.borderRadius = 12,
  });

  final DownloadedMangaComic comic;
  final String? heroTag;
  final VoidCallback? onTap;
  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final localPath = comic.localCoverPath?.trim();
    final radius = BorderRadius.circular(borderRadius);
    Widget child;
    if (localPath != null && localPath.isNotEmpty) {
      final file = File(localPath);
      if (file.existsSync()) {
        child = ClipRRect(
          borderRadius: radius,
          child: Image.file(
            file,
            width: width,
            height: height,
            fit: BoxFit.cover,
          ),
        );
      } else {
        child = _buildFallback(context, radius);
      }
    } else if (comic.coverUrl.trim().isNotEmpty) {
      child = ClipRRect(
        borderRadius: radius,
        child: HazukiCachedImage(
          url: comic.coverUrl,
          sourceKey: comic.sourceKey,
          width: width,
          height: height,
          fit: BoxFit.cover,
        ),
      );
    } else {
      child = _buildFallback(context, radius);
    }
    if (heroTag != null) {
      child = Hero(tag: heroTag!, child: child);
    }
    if (onTap != null) {
      child = InkWell(borderRadius: radius, onTap: onTap, child: child);
    }
    return child;
  }

  Widget _buildFallback(BuildContext context, BorderRadius radius) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: radius,
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.image_not_supported_outlined),
    );
  }
}

class DownloadedComicCoverPreviewPage extends StatelessWidget {
  const DownloadedComicCoverPreviewPage({
    super.key,
    required this.comic,
    required this.heroTag,
  });

  final DownloadedMangaComic comic;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    final localPath = comic.localCoverPath?.trim();
    final networkUrl = comic.coverUrl.trim();
    final placeholderColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.06);

    Widget imageChild;
    if (localPath != null &&
        localPath.isNotEmpty &&
        File(localPath).existsSync()) {
      imageChild = Image.file(File(localPath), fit: BoxFit.contain);
    } else if (networkUrl.isNotEmpty) {
      imageChild = HazukiCachedImage(
        url: networkUrl,
        sourceKey: comic.sourceKey,
        fit: BoxFit.contain,
        loading: Container(width: 220, height: 300, color: placeholderColor),
        error: Container(
          width: 220,
          height: 300,
          color: placeholderColor,
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image_outlined),
        ),
      );
    } else {
      imageChild = Container(
        width: 220,
        height: 300,
        color: placeholderColor,
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image_outlined),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).pop(),
      child: SafeArea(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 32),
              child: Hero(
                tag: heroTag,
                child: Material(
                  color: Colors.transparent,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      child: imageChild,
                    ),
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
