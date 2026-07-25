using Travle.Model.Exceptions;
using SixLabors.ImageSharp;
using SixLabors.ImageSharp.Formats.Jpeg;
using SixLabors.ImageSharp.PixelFormats;
using SixLabors.ImageSharp.Processing;

namespace Travle.Services.Imaging
{
    /// <summary>
    /// <see cref="IThumbnailGenerator"/> backed by SixLabors.ImageSharp — a fully managed, cross-platform
    /// codec (no native GDI+/System.Drawing dependency, so it runs unchanged in the Linux API container).
    /// Stateless and thread-safe, so it is registered as a singleton.
    /// </summary>
    public sealed class ImageSharpThumbnailGenerator : IThumbnailGenerator
    {
        private const string JpegContentType = "image/jpeg";

        /// <summary>Longest-edge bound for a list thumbnail (px). Keeps thumbnails in the ~15–30 KB range.</summary>
        private const int ThumbnailMaxEdge = 400;

        private const int PlaceholderWidth = 800;
        private const int PlaceholderHeight = 600;
        private const int JpegQuality = 80;

        public async Task<(byte[] Thumbnail, string ContentType)> GenerateThumbnailAsync(byte[] original, CancellationToken cancellationToken = default)
        {
            Image image;
            try
            {
                // Decode is the only step that can fail on caller-supplied bytes: a file can carry a valid
                // magic-byte header yet be truncated/corrupt. Translate that to a friendly 400 rather than
                // letting the codec's exception surface as a 500 (course §H).
                using var input = new MemoryStream(original);
                image = await Image.LoadAsync(input, cancellationToken);
            }
            catch (ImageFormatException)
            {
                throw new BusinessRuleException("The image could not be read. Please upload a valid JPEG or PNG image.");
            }

            using (image)
            {
                // ResizeMode.Max fits the image inside the box preserving aspect ratio and never upscales a
                // smaller source (DownOnly-like behaviour: a tiny image stays its own size).
                image.Mutate(ctx => ctx.Resize(new ResizeOptions
                {
                    Mode = ResizeMode.Max,
                    Size = new Size(ThumbnailMaxEdge, ThumbnailMaxEdge)
                }));

                using var output = new MemoryStream();
                await image.SaveAsJpegAsync(output, new JpegEncoder { Quality = JpegQuality }, cancellationToken);
                return (output.ToArray(), JpegContentType);
            }
        }

        public async Task<byte[]> GeneratePlaceholderJpegAsync(string seedText, CancellationToken cancellationToken = default)
        {
            var colour = ColourFromSeed(seedText);

            using var image = new Image<Rgb24>(PlaceholderWidth, PlaceholderHeight, colour);
            using var output = new MemoryStream();
            await image.SaveAsJpegAsync(output, new JpegEncoder { Quality = JpegQuality }, cancellationToken);
            return output.ToArray();
        }

        // Deterministic, reasonably-distinct colour from the text (stable across runs so the seed image
        // never changes). A muted mid-tone palette avoids harsh colours (course §6 "no garish colours").
        private static Rgb24 ColourFromSeed(string seedText)
        {
            var hash = 17;
            foreach (var ch in seedText)
            {
                hash = unchecked(hash * 31 + ch);
            }

            // Keep each channel in [64, 192] so the block is a calm mid-tone.
            byte Channel(int shift) => (byte)(64 + (((uint)hash >> shift) & 0xFF) % 128);
            return new Rgb24(Channel(0), Channel(8), Channel(16));
        }
    }
}
