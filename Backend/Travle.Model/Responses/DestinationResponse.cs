namespace Travle.Model.Responses
{
    /// <summary>
    /// A tourist destination, in the single shape used by every read path — the paginated list, the
    /// detail view, and edit prefill. Reference fields are flattened to names (never raw ids on screen)
    /// and <see cref="Status"/> is the enum name. Only the <see cref="PrimaryThumbnail"/> (a small
    /// ~15–30 KB thumbnail for list cards) carries bytes; the <see cref="Images"/> collection is
    /// metadata only, and full image bytes come from the dedicated image endpoint (§8.2 / rule 12).
    /// </summary>
    public class DestinationResponse
    {
        public int Id { get; set; }

        public string Name { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;

        public int CategoryId { get; set; }
        public string? CategoryName { get; set; }

        public int CityId { get; set; }
        public string? CityName { get; set; }
        public string? RegionName { get; set; }
        public string? CountryName { get; set; }

        public double Latitude { get; set; }
        public double Longitude { get; set; }

        /// <summary>
        /// Optional informative entrance fee (KM) paid at the destination — never part of a tour's price.
        /// Null = free/unknown; treat the amount as an approximate "bring around X" guide.
        /// </summary>
        public decimal? EntranceFee { get; set; }

        /// <summary>Pending / Approved / Rejected — the enum name, never the raw int.</summary>
        public string Status { get; set; } = string.Empty;

        public bool IsFeatured { get; set; }
        public double AverageRating { get; set; }

        /// <summary>Number of non-removed reviews behind <see cref="AverageRating"/> (shown as "(N reviews)").</summary>
        public int ReviewCount { get; set; }

        public int ViewCount { get; set; }

        /// <summary>Whether the current user has this destination in their favorites (drives the heart state).</summary>
        public bool IsFavorite { get; set; }

        public int SubmittedByUserId { get; set; }
        public string? SubmittedByUsername { get; set; }

        public int? ModeratedByUserId { get; set; }
        public string? ModeratedByUsername { get; set; }
        public DateTime? ModeratedAt { get; set; }
        public string? RejectionReason { get; set; }

        /// <summary>Tags (id + name) — ids let the edit form preselect chips; names are shown.</summary>
        public List<TagRef> Tags { get; set; } = new List<TagRef>();

        /// <summary>Image metadata (ids/order); fetch each full image via the image endpoint.</summary>
        public List<DestinationImageResponse> Images { get; set; } = new List<DestinationImageResponse>();

        /// <summary>The primary image's thumbnail bytes for list cards (null when the destination has no image).</summary>
        public byte[]? PrimaryThumbnail { get; set; }
        public string? PrimaryThumbnailContentType { get; set; }

        public DateTime CreatedAt { get; set; }
        public DateTime? ModifiedAt { get; set; }
    }
}
