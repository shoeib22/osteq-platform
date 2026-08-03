import 'package:flutter/material.dart';
import '../core/supabase_client.dart';
import '../theme/app_colors.dart';

/// Renders a product photo, or an elegant placeholder when none has been uploaded yet —
/// every call site (catalog grid, product detail) shows the same placeholder instead of
/// each screen inventing its own "no image" fallback.
class ProductImage extends StatelessWidget {
  const ProductImage({super.key, required this.imagePath, this.borderRadius});

  /// The relative storage path returned by the API (e.g. "productId/uuid.png"), not a
  /// full URL — resolved against this app's own SUPABASE_URL here.
  final String? imagePath;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final path = imagePath;
    final content = path == null
        ? _Placeholder()
        : Image.network(
            resolveStoragePublicUrl('product-images', path),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const _Placeholder(loading: true);
            },
            errorBuilder: (context, error, stack) => const _Placeholder(),
          );

    if (borderRadius == null) return content;
    return ClipRRect(borderRadius: borderRadius!, child: content);
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({this.loading = false});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surfaceRaised, AppColors.surface],
        ),
      ),
      alignment: Alignment.center,
      child: loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.diamond_outlined, color: AppColors.goldMuted, size: 32),
    );
  }
}
