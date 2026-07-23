import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Circular profile avatar. Decodes its base64 source **once** and caches the
/// bytes (re-decoding only when the source string changes) — never inside
/// `build`, per the image-handling rule (doc 08 / constraint §12). Falls back to
/// initials or a person icon when there is no image.
class ProfileAvatar extends StatefulWidget {
  const ProfileAvatar({
    super.key,
    this.base64Image,
    this.radius = 28,
    this.initials,
  });

  /// Raw base64 image bytes as sent by the API (`byte[]` → base64 string). Null
  /// or empty renders the placeholder.
  final String? base64Image;
  final double radius;

  /// Optional initials shown when there is no image (else a person icon).
  final String? initials;

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(ProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.base64Image != widget.base64Image) {
      _decode();
    }
  }

  void _decode() {
    final raw = widget.base64Image;
    if (raw == null || raw.isEmpty) {
      _bytes = null;
      return;
    }
    try {
      _bytes = base64Decode(raw);
    } catch (_) {
      // Malformed payload → fall back to the placeholder rather than crash.
      _bytes = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bytes = _bytes;
    if (bytes != null) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundImage: MemoryImage(bytes),
      );
    }
    final initials = widget.initials?.trim();
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: scheme.primary,
      child: (initials != null && initials.isNotEmpty)
          ? Text(
              initials,
              style: TextStyle(
                color: scheme.onPrimary,
                fontWeight: FontWeight.w600,
                fontSize: widget.radius * 0.7,
              ),
            )
          : Icon(Icons.person, color: scheme.onPrimary, size: widget.radius),
    );
  }
}
