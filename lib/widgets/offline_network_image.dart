import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../theme/app_colors.dart';

/// Widget reutilizable para mostrar imágenes de red con soporte offline.
/// Utiliza `cached_network_image` + `flutter_cache_manager` para aprovechar
/// las descargas que hacemos manualmente durante el prefetch.
class OfflineNetworkImage extends StatelessWidget {
  const OfflineNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorChild,
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorChild;

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (imageUrl.isEmpty) {
      content = errorChild ?? _defaultError();
    } else {
      content = CachedNetworkImage(
        imageUrl: imageUrl,
        cacheManager: DefaultCacheManager(),
        fit: fit,
        width: width,
        height: height,
        placeholder: (context, url) => placeholder ?? _defaultPlaceholder(),
        errorWidget: (context, url, error) => errorChild ?? _defaultError(),
      );
    }

    if (borderRadius != null) {
      content = ClipRRect(
        borderRadius: borderRadius!,
        child: content,
      );
    }

    if (width != null || height != null) {
      content = SizedBox(
        width: width,
        height: height,
        child: content,
      );
    }

    return content;
  }

  Widget _defaultPlaceholder() {
    return Container(
      color: Colors.grey.withAlpha(26),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _defaultError() {
    return Container(
      color: Colors.grey.withAlpha(26),
      alignment: Alignment.center,
      child: Icon(
        Icons.image_outlined,
        size: 32,
        color: AppColors.textSecondary.withAlpha(77),
      ),
    );
  }
}
