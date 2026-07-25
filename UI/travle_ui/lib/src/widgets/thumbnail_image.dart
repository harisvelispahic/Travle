import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:travle_core/travle_core.dart';

import '../theme/tokens.dart';

/// A fixed-size rounded thumbnail for list cards, decoding its base64 source
/// **once** (cached in state, re-decoded only when the source changes) — never
/// inside `build`, per the image-handling rule (doc 08 / constraint §12). Falls
/// back to a muted placeholder icon when there is no image.
class ThumbnailImage extends StatefulWidget {
  const ThumbnailImage({
    super.key,
    this.base64,
    this.width = 64,
    this.height = 64,
    this.radius = TravleTokens.radius,
    this.placeholderIcon = Icons.image_outlined,
  });

  /// Raw base64 image bytes as sent by the API. Null/empty renders the placeholder.
  final String? base64;
  final double width;
  final double height;
  final double radius;
  final IconData placeholderIcon;

  @override
  State<ThumbnailImage> createState() => _ThumbnailImageState();
}

class _ThumbnailImageState extends State<ThumbnailImage> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(ThumbnailImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.base64 != widget.base64) {
      _decode();
    }
  }

  // Decode once here (cached in state) — never inside build.
  void _decode() => _bytes = ImageCodec.decode(widget.base64);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(widget.radius);
    final bytes = _bytes;

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: bytes != null
            ? Image.memory(bytes, fit: BoxFit.cover)
            : Container(
                color: scheme.surfaceContainerHighest,
                child: Icon(
                  widget.placeholderIcon,
                  color: scheme.onSurfaceVariant,
                  size: widget.width * 0.4,
                ),
              ),
      ),
    );
  }
}
