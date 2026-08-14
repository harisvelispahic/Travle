import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A square, tappable image card used for multi-select grids (e.g. the onboarding
/// category picker): a 1:1 illustration on top, the title + optional description
/// below, and a check badge + accent border marking the selected state. The caller
/// supplies already-decoded [imageBytes] (decoded once, off the build path, per the
/// image-handling rule — constraint §12); null renders a muted placeholder icon.
///
/// The accent border is drawn by an outer, *unclipped* container and the content is
/// clipped a hair tighter (radius − border width) so it nests cleanly inside the
/// stroke — otherwise clipping the border at the corners shaves its outer edge and
/// the rounded corners look broken.
class SelectableImageCard extends StatelessWidget {
  const SelectableImageCard({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.description,
    this.imageBytes,
  });

  final String title;
  final String? description;
  final Uint8List? imageBytes;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bytes = imageBytes;
    final hasDescription = description != null && description!.isNotEmpty;

    final borderWidth = selected ? 2.0 : 1.0;
    final outerRadius = BorderRadius.circular(TravleTokens.radius);
    final innerRadius =
        BorderRadius.circular(TravleTokens.radius - borderWidth);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: outerRadius,
        border: Border.all(
          color: selected ? scheme.primary : scheme.outlineVariant,
          width: borderWidth,
        ),
      ),
      child: ClipRRect(
        borderRadius: innerRadius,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // The illustration keeps its natural 1:1 square (the sources are square) — shown in
                    // full, never cropped to fill leftover space. Title + description sit below it.
                    AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        color: scheme.surfaceContainerHighest,
                        alignment: Alignment.center,
                        child: bytes != null
                            ? Image.memory(bytes,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity)
                            : Icon(Icons.image_outlined,
                                color: scheme.onSurfaceVariant, size: 32),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(TravleTokens.space12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            if (hasDescription) ...[
                              const SizedBox(height: TravleTokens.space4),
                              // No line cap: the grid reserves height for the full
                              // wrapped text (see the onboarding cell sizing), so the
                              // whole description is shown rather than truncated.
                              Flexible(
                                child: Text(
                                  description!,
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(color: scheme.onSurfaceVariant),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (selected)
                  Positioned(
                    top: TravleTokens.space8,
                    right: TravleTokens.space8,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child:
                          Icon(Icons.check, size: 16, color: scheme.onPrimary),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
