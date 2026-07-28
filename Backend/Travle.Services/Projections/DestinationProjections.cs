using Travle.Model.Responses;
using Travle.Services.Database;

namespace Travle.Services.Projections
{
    /// <summary>
    /// The single Destination → <see cref="DestinationResponse"/> projection, shared by the destinations
    /// service (list / detail / moderation) and the favorites service. Runs entirely in SQL and pulls only
    /// the primary image's small thumbnail — never any full <c>ImageData</c> (§8.2 / rule 12). The
    /// thumbnail content type (always JPEG) and the per-user <c>IsFavorite</c> flag are applied after
    /// materialization by the caller, since they need a constant / the current user rather than the row.
    /// </summary>
    public static class DestinationProjections
    {
        /// <summary>Server thumbnails are always JPEG (the generator guarantees it).</summary>
        public const string ThumbnailContentType = "image/jpeg";

        public static IQueryable<DestinationResponse> ProjectToResponse(IQueryable<Destination> query)
            => query.Select(d => new DestinationResponse
            {
                Id = d.Id,
                Name = d.Name,
                Description = d.Description,
                CategoryId = d.CategoryId,
                CategoryName = d.Category.Name,
                CityId = d.CityId,
                CityName = d.City.Name,
                RegionName = d.City.Region.Name,
                CountryName = d.City.Region.Country.Name,
                Latitude = d.Latitude,
                Longitude = d.Longitude,
                EntranceFee = d.EntranceFee,
                Status = d.Status.ToString(),
                IsFeatured = d.IsFeatured,
                AverageRating = d.AverageRating,
                ReviewCount = d.Reviews.Count(r => !r.IsRemoved),
                ViewCount = d.ViewCount,
                SubmittedByUserId = d.SubmittedByUserId,
                SubmittedByUsername = d.SubmittedByUser.Username,
                ModeratedByUserId = d.ModeratedByUserId,
                ModeratedByUsername = d.ModeratedByUser != null ? d.ModeratedByUser.Username : null,
                ModeratedAt = d.ModeratedAt,
                RejectionReason = d.RejectionReason,
                Tags = d.DestinationTags
                    .Select(dt => new TagRef { Id = dt.TagId, Name = dt.Tag.Name })
                    .ToList(),
                Images = d.Images
                    .OrderBy(i => i.SortOrder)
                    .Select(i => new DestinationImageResponse
                    {
                        Id = i.Id,
                        ContentType = i.ContentType,
                        SortOrder = i.SortOrder
                    })
                    .ToList(),
                PrimaryThumbnail = d.Images
                    .OrderBy(i => i.SortOrder)
                    .Select(i => i.ThumbnailData)
                    .FirstOrDefault(),
                CreatedAt = d.CreatedAt,
                ModifiedAt = d.ModifiedAt
            });

        /// <summary>Thumbnails are always JPEG, so the content type is a constant set after materialization.</summary>
        public static void FinalizeThumbnails(IEnumerable<DestinationResponse> items)
        {
            foreach (var item in items)
            {
                FinalizeThumbnail(item);
            }
        }

        public static void FinalizeThumbnail(DestinationResponse item)
            => item.PrimaryThumbnailContentType = item.PrimaryThumbnail is { Length: > 0 } ? ThumbnailContentType : null;
    }
}
