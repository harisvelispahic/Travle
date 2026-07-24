import 'image_codec.dart';

/// Upload helpers for a supporting **document** — a superset of [ImageCodec] that
/// also accepts PDF (role-application attachments allow PDF or an image). Pure
/// logic; the server re-validates every upload by its magic bytes, and
/// [sniffContentType] mirrors that so the client can reject early.
class DocumentCodec {
  DocumentCodec._();

  /// Content types the API accepts for a supporting document (PDF + images).
  static const List<String> allowedContentTypes = <String>[
    'application/pdf',
    'image/jpeg',
    'image/png',
  ];

  /// Maximum upload size the API accepts for a document (5 MB).
  static const int maxBytes = 5 * 1024 * 1024;

  /// Returns the document MIME type from the leading magic bytes — `%PDF` for a
  /// PDF, otherwise the image types via [ImageCodec.sniffContentType] — or null
  /// for anything else. Mirrors the server's magic-byte check.
  static String? sniffContentType(List<int> bytes) {
    if (bytes.length >= 4 &&
        bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46) {
      return 'application/pdf';
    }
    return ImageCodec.sniffContentType(bytes);
  }

  /// Encodes raw bytes to a base64 string for sending to the API.
  static String encode(List<int> bytes) => ImageCodec.encode(bytes);

  /// The conventional file extension (including the leading dot) for an allowed
  /// document content type, or an empty string if unknown — used to name a
  /// downloaded attachment.
  static String extensionForContentType(String? contentType) {
    switch (contentType) {
      case 'application/pdf':
        return '.pdf';
      case 'image/png':
        return '.png';
      case 'image/jpeg':
        return '.jpg';
      default:
        return '';
    }
  }
}
