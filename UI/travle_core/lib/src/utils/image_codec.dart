import 'dart:convert';
import 'dart:typed_data';

/// Base64 ⇄ bytes helpers and magic-byte MIME sniffing for images exchanged with
/// the API (a `byte[]` column serializes to a base64 string). Pure logic — no
/// widgets — so it lives in core and is shared by the UI avatar and any
/// image-upload screen. The server re-validates every upload by its magic bytes;
/// [sniffContentType] mirrors that so the client can reject early.
class ImageCodec {
  ImageCodec._();

  /// Image content types the API accepts for a profile picture.
  static const List<String> allowedImageContentTypes = <String>[
    'image/jpeg',
    'image/png',
  ];

  /// Maximum upload size the API accepts for a profile image (5 MB).
  static const int maxImageBytes = 5 * 1024 * 1024;

  /// Decodes an API base64 image string to bytes. Null, empty, or malformed
  /// input returns null, so callers can render a placeholder instead of crashing.
  static Uint8List? decode(String? base64) {
    if (base64 == null || base64.isEmpty) return null;
    try {
      return base64Decode(base64);
    } catch (_) {
      return null;
    }
  }

  /// Encodes raw bytes to a base64 string for sending to the API.
  static String encode(List<int> bytes) => base64Encode(bytes);

  /// Returns the image MIME type from the leading magic bytes (PNG or JPEG), or
  /// null for anything else — mirrors the server's magic-byte check.
  static String? sniffContentType(List<int> bytes) {
    if (bytes.length >= 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    return null;
  }
}
