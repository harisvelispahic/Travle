namespace Travle.Services.Imaging
{
    /// <summary>
    /// Produces the small list thumbnails the API stores alongside each full image, so lists ship a
    /// ~15–30 KB image instead of the original (§8.2 / 03 §5). Thumbnails are generated server-side from
    /// the uploaded bytes — the client never supplies one (rule 3). Also mints solid placeholder images
    /// for the destination seed, so every seeded row has an image on first run without committing blobs.
    /// </summary>
    public interface IThumbnailGenerator
    {
        /// <summary>
        /// Decodes <paramref name="original"/>, downscales it to fit a small bounding box (aspect
        /// preserved), and re-encodes it as JPEG. Returns the thumbnail bytes and their content type
        /// (always <c>image/jpeg</c>). Throws if the input is not a decodable image.
        /// </summary>
        Task<(byte[] Thumbnail, string ContentType)> GenerateThumbnailAsync(byte[] original, CancellationToken cancellationToken = default);

        /// <summary>
        /// Like <see cref="GenerateThumbnailAsync"/> but re-encodes as PNG, so an alpha channel survives
        /// (category illustrations may be transparent — a JPEG thumbnail would flatten transparency to
        /// black). Returns the thumbnail bytes and their content type (always <c>image/png</c>).
        /// </summary>
        Task<(byte[] Thumbnail, string ContentType)> GeneratePngThumbnailAsync(byte[] original, CancellationToken cancellationToken = default);

        /// <summary>
        /// Generates a full-size solid-colour placeholder JPEG whose colour is derived deterministically
        /// from <paramref name="seedText"/> (so the same destination always seeds the same image).
        /// </summary>
        Task<byte[]> GeneratePlaceholderJpegAsync(string seedText, CancellationToken cancellationToken = default);
    }
}
