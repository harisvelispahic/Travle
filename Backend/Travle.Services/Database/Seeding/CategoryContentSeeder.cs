using System.Reflection;
using Travle.Services.Imaging;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace Travle.Services.Database.Seeding
{
    /// <summary>
    /// Idempotent runtime backfill of the onboarding-card content on <see cref="DestinationCategory"/>:
    /// each category's short description and its illustration (full PNG + generated thumbnail). Binary blobs
    /// can't ride along in a migration/HasData, so — like the destination placeholder images — this runs on
    /// startup after seeding. The description is set on any category still missing one; the image is applied
    /// only when the matching embedded PNG asset is present, so this is safe to run before every asset ships.
    /// </summary>
    public static class CategoryContentSeeder
    {
        // Embedded illustrations live at Database/Seeding/CategoryImages/<slug>.png (see the csproj). The
        // manifest name is matched by suffix so it is independent of the assembly's root namespace.
        private const string ResourceMarker = ".CategoryImages.";

        public static async Task SeedAsync(
            TravleDbContext db,
            IThumbnailGenerator thumbnailGenerator,
            ILogger logger,
            CancellationToken ct = default)
        {
            var categoriesByName = await db.DestinationCategories
                .ToDictionaryAsync(c => c.Name, ct);

            var assembly = typeof(CategoryContentSeeder).Assembly;
            var resourceNames = assembly.GetManifestResourceNames();

            int descriptions = 0;
            int images = 0;

            foreach (var entry in SeedCategoryContent.Entries)
            {
                if (!categoriesByName.TryGetValue(entry.Name, out var category))
                {
                    continue;
                }

                if (string.IsNullOrWhiteSpace(category.Description))
                {
                    category.Description = entry.Description;
                    descriptions++;
                }

                if (category.Image is null || category.Image.Length == 0)
                {
                    var bytes = ReadImage(assembly, resourceNames, entry.Slug);
                    if (bytes is not null)
                    {
                        var (thumbnail, contentType) = await thumbnailGenerator.GeneratePngThumbnailAsync(bytes, ct);
                        category.Image = bytes;
                        category.ImageContentType = contentType;
                        category.ImageThumbnail = thumbnail;
                        images++;
                    }
                }
            }

            if (descriptions == 0 && images == 0)
            {
                return;
            }

            await db.SaveChangesAsync(ct);
            logger.LogInformation(
                "Seeded category content: {Descriptions} description(s), {Images} illustration(s).",
                descriptions, images);
        }

        private static byte[]? ReadImage(Assembly assembly, string[] resourceNames, string slug)
        {
            var suffix = $"{ResourceMarker}{slug}.png";
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
    }
}
