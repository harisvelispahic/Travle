namespace Travle.Services.Security
{
    /// <summary>
    /// Validates uploaded files by their leading "magic bytes" rather than by trusting the declared
    /// content type or a file extension (course §I: uploads validate MIME type and magic bytes). Used
    /// for the optional role-application document; the profile-image upload can reuse the image
    /// signatures here when that validation lands.
    /// </summary>
    public static class FileSignatureValidator
    {
        // The byte prefix each allowed content type must begin with. JPEG has several valid third
        // bytes, so only the two-byte SOI marker is required. PDF files start with "%PDF".
        private static readonly Dictionary<string, byte[][]> Signatures = new(StringComparer.OrdinalIgnoreCase)
        {
            ["image/jpeg"] = new[] { new byte[] { 0xFF, 0xD8, 0xFF } },
            ["image/png"] = new[] { new byte[] { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A } },
            ["application/pdf"] = new[] { new byte[] { 0x25, 0x50, 0x44, 0x46 } }
        };

        /// <summary>The content types this validator recognises (for building an allow-list message).</summary>
        public static IReadOnlyCollection<string> AllowedContentTypes => Signatures.Keys;

        /// <summary>
        /// True when <paramref name="content"/> is non-empty, <paramref name="contentType"/> is a
        /// recognised type, and the content's leading bytes match that type's signature.
        /// </summary>
        public static bool IsValid(byte[]? content, string? contentType)
        {
            if (content is null || content.Length == 0 || string.IsNullOrWhiteSpace(contentType))
            {
                return false;
            }

            if (!Signatures.TryGetValue(contentType.Trim(), out var candidates))
            {
                return false;
            }

            foreach (var signature in candidates)
            {
                if (content.Length >= signature.Length && content.AsSpan(0, signature.Length).SequenceEqual(signature))
                {
                    return true;
                }
            }

            return false;
        }
    }
}
