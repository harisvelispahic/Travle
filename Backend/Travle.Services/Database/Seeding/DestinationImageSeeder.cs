using System.Globalization;
using System.Reflection;
using System.Text;
using System.Text.RegularExpressions;
using Travle.Services.Imaging;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace Travle.Services.Database.Seeding
{
    /// <summary>
    /// Idempotent runtime backfill of destination photography. Every destination gets one image: the
    /// embedded photo shipped for it when there is one, otherwise the generated colour placeholder that
    /// stands in for the handful of entries with no identifiable real-world subject (walks, trails).
    ///
    /// Binary blobs can't ride along in a migration/HasData, so — like <see cref="CategoryContentSeeder"/> —
    /// this runs on startup after migration. The photos are committed to the repository and embedded in this
    /// assembly, so seeding needs no network access and `docker compose up` stays self-contained.
    /// </summary>
    public static class DestinationImageSeeder
    {
        // Embedded photos live at Database/Seeding/DestinationImages/&lt;slug&gt;.jpg (see the csproj). The
        // manifest name is matched by suffix so it is independent of the assembly's root namespace.
        private const string ResourceMarker = ".DestinationImages.";

        private static readonly Regex NonAlphanumeric = new("[^a-z0-9]+", RegexOptions.Compiled);

        public static async Task SeedAsync(
            TravleDbContext db,
            IThumbnailGenerator thumbnailGenerator,
            ILogger logger,
            CancellationToken ct = default)
        {
            var assembly = typeof(DestinationImageSeeder).Assembly;
            var resourceNames = assembly.GetManifestResourceNames();

            var added = await AddMissingImagesAsync(db, thumbnailGenerator, assembly, resourceNames, ct);
            var upgraded = await ReplacePlaceholdersAsync(db, thumbnailGenerator, assembly, resourceNames, ct);

            if (added == 0 && upgraded == 0)
            {
                return;
            }

            logger.LogInformation(
                "Seeded destination images: {Added} added, {Upgraded} placeholder(s) replaced with photos.",
                added, upgraded);
        }

        // First boot on a fresh database: every destination is imageless.
        private static async Task<int> AddMissingImagesAsync(
            TravleDbContext db,
            IThumbnailGenerator thumbnailGenerator,
            Assembly assembly,
            string[] resourceNames,
            CancellationToken ct)
        {
            var destinations = await db.Destinations
                .Where(d => !d.Images.Any())
                .Select(d => new { d.Id, d.Name })
                .ToListAsync(ct);

            if (destinations.Count == 0)
            {
                return 0;
            }

            foreach (var destination in destinations)
            {
                var photo = ReadPhoto(assembly, resourceNames, Slugify(destination.Name));
                var image = photo ?? await thumbnailGenerator.GeneratePlaceholderJpegAsync(destination.Name, ct);
                var (thumbnail, contentType) = await thumbnailGenerator.GenerateThumbnailAsync(image, ct);

                db.DestinationImages.Add(new DestinationImage
                {
                    DestinationId = destination.Id,
                    ImageData = image,
                    ThumbnailData = thumbnail,
                    ContentType = contentType,
                    SortOrder = 0
                });
            }

            await db.SaveChangesAsync(ct);
            return destinations.Count;
        }

        // Databases seeded before the photos shipped already hold a placeholder, so the "no images" check
        // above skips them forever. The placeholder is deterministic per destination name, so regenerating
        // it and comparing bytes identifies one exactly — which means a genuinely uploaded image is never
        // mistaken for a placeholder and never overwritten.
        private static async Task<int> ReplacePlaceholdersAsync(
            TravleDbContext db,
            IThumbnailGenerator thumbnailGenerator,
            Assembly assembly,
            string[] resourceNames,
            CancellationToken ct)
        {
            var candidates = await db.Destinations
                .Where(d => d.Images.Count == 1)
                .Select(d => new { d.Id, d.Name, Image = d.Images.First() })
                .ToListAsync(ct);

            var replaced = 0;
            foreach (var candidate in candidates)
            {
                var photo = ReadPhoto(assembly, resourceNames, Slugify(candidate.Name));
                if (photo is null)
                {
                    continue;
                }

                var placeholder = await thumbnailGenerator.GeneratePlaceholderJpegAsync(candidate.Name, ct);
                if (!candidate.Image.ImageData.AsSpan().SequenceEqual(placeholder))
                {
                    continue;
                }

                var (thumbnail, contentType) = await thumbnailGenerator.GenerateThumbnailAsync(photo, ct);
                candidate.Image.ImageData = photo;
                candidate.Image.ThumbnailData = thumbnail;
                candidate.Image.ContentType = contentType;
                replaced++;
            }

            if (replaced > 0)
            {
                await db.SaveChangesAsync(ct);
            }

            return replaced;
        }

        private static byte[]? ReadPhoto(Assembly assembly, string[] resourceNames, string slug)
        {
            var suffix = $"{ResourceMarker}{slug}.jpg";
            var resourceName = resourceNames.FirstOrDefault(
                n => n.EndsWith(suffix, StringComparison.OrdinalIgnoreCase));
            if (resourceName is null)
            {
                return null;
            }

            using var stream = assembly.GetManifestResourceStream(resourceName);
            if (stream is null)
            {
                return null;
            }

            using var memory = new MemoryStream();
            stream.CopyTo(memory);
            return memory.ToArray();
        }

        /// <summary>
        /// Destination name to asset file name. MUST stay in sync with `slugify` in
        /// tools/destination-images/fetch_images.py, which names the files this looks up.
        /// </summary>
        private static string Slugify(string name)
        {
            var decomposed = name.Normalize(NormalizationForm.FormKD);
            var builder = new StringBuilder(decomposed.Length);
            foreach (var ch in decomposed)
            {
                if (CharUnicodeInfo.GetUnicodeCategory(ch) != UnicodeCategory.NonSpacingMark)
                {
                    builder.Append(ch);
                }
            }

            // Đ and Ł carry a stroke rather than a combining mark, so decomposition leaves them intact.
            var ascii = builder
                .Replace("Đ", "D").Replace("đ", "d")
                .Replace("Ł", "L").Replace("ł", "l")
                .ToString()
                .ToLowerInvariant();

            return NonAlphanumeric.Replace(ascii, "-").Trim('-');
        }
    }
}
