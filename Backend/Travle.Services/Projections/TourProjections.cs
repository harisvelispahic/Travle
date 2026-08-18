using Travle.Model.Responses;
using Travle.Services.Database;

namespace Travle.Services.Projections
{
    /// <summary>
    /// The single Tour → <see cref="TourResponse"/> list/card projection, shared by the tours service
    /// (list / detail) and the favorites service. Runs entirely in SQL and pulls only the cover thumbnail
    /// (the ordered-first destination's primary thumbnail) plus lightweight counts and the on-read rating
    /// aggregate — never any full <c>ImageData</c> (§8.2 / rule 12). The thumbnail content type and the
    /// per-user <c>IsFavorite</c> flag are applied after materialization by the caller. Detail-only graph
    /// (ordered stops, upcoming schedules) is layered on by the tours service, not here.
    /// </summary>
    public static class TourProjections
    {
        /// <summary>Server thumbnails are always JPEG (the generator guarantees it).</summary>
        public const string ThumbnailContentType = "image/jpeg";

        public static IQueryable<TourResponse> ProjectToListResponse(IQueryable<Tour> query, DateTime now)
            => query.Select(t => new TourResponse
            {
                Id = t.Id,
                Name = t.Name,
                Description = t.Description,
                DurationMinutes = t.DurationMinutes,
                PricePerPerson = t.PricePerPerson,
                Capacity = t.Capacity,
                TourTypeId = t.TourTypeId,
                TourTypeName = t.TourType.Name,
                OrganizerId = t.OrganizerId,
                OrganizerName = t.Organizer.FirstName + " " + t.Organizer.LastName,
                IsActive = t.IsActive,
                // A tour is "unavailable" the moment any stop leaves the approved catalogue (edited back to
                // Pending / rejected). Travelers never see such a tour; the organizer sees it flagged.
                HasUnavailableDestination = t.TourDestinations.Any(td => td.Destination.Status != DestinationStatus.Approved),
                // Tour rating is computed on read — a tour has no denormalized rating column (03 §4). A
                // suspended author's review is excluded from the public aggregate (reappears on unsuspend).
                AverageRating = t.Reviews.Where(r => !r.IsRemoved && !r.User.IsSuspended).Select(r => (double?)r.Rating).Average() ?? 0d,
                ReviewCount = t.Reviews.Count(r => !r.IsRemoved && !r.User.IsSuspended),
                DestinationCount = t.TourDestinations.Count,
                // Per-person on-site entrance fees (informative; never part of the Travle price).
                EntranceFeesPerPerson = t.TourDestinations.Sum(td => td.Destination.EntranceFee ?? 0m),
                UpcomingScheduleCount = t.Schedules.Count(s => s.Status == ScheduleStatus.Active && s.StartsAt > now),
                NextDepartureAt = t.Schedules
                    .Where(s => s.Status == ScheduleStatus.Active && s.StartsAt > now)
                    .OrderBy(s => s.StartsAt)
                    .Select(s => (DateTime?)s.StartsAt)
                    .FirstOrDefault(),
                PrimaryThumbnail = t.TourDestinations
                    .OrderBy(td => td.SortOrder)
                    .Select(td => td.Destination.Images
                        .OrderBy(i => i.SortOrder)
                        .Select(i => i.ThumbnailData)
                        .FirstOrDefault())
                    .FirstOrDefault(),
                CreatedAt = t.CreatedAt,
                ModifiedAt = t.ModifiedAt
            });

        public static void FinalizeThumbnails(IEnumerable<TourResponse> items)
        {
            foreach (var item in items)
            {
                FinalizeThumbnail(item);
            }
        }

        public static void FinalizeThumbnail(TourResponse item)
            => item.PrimaryThumbnailContentType = item.PrimaryThumbnail is { Length: > 0 } ? ThumbnailContentType : null;
    }
}
