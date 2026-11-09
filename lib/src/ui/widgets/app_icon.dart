import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppIcon extends StatelessWidget {
  const AppIcon({super.key, required this.path, this.size = 48});

  final String? path;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(size / 4),
      ),
      child: Icon(
        Icons.apps_rounded,
        size: size * 0.6,
        color: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
    );

    final iconPath = path;
    if (iconPath == null) return fallback;

    final file = File(iconPath);
    if (iconPath.toLowerCase().endsWith('.svg')) {
      return SvgPicture.file(
        file,
        width: size,
        height: size,
        placeholderBuilder: (_) => fallback,
        errorBuilder: (_, _, _) => fallback,
      );
    }
    return Image.file(
      file,
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}
