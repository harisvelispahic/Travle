namespace Travle.Services.Database
{
    /// <summary>Reference table. Classifies destinations (Historical, Natural, Religious, …); a recommender feature.</summary>
    public class DestinationCategory : BaseEntity
    {
        public string Name { get; set; } = string.Empty;

        /// <summary>Short marketing blurb shown on the onboarding category cards. Null until seeded/set by an admin.</summary>
        public string? Description { get; set; }

        /// <summary>Full illustration bytes (PNG). Never selected onto a list DTO — served only by the dedicated
        /// image endpoint, following the byte[]-in-DB / thumbnail-in-list image rule (§12).</summary>
        public byte[]? Image { get; set; }

        /// <summary>MIME type of <see cref="Image"/> (always <c>image/png</c> for the seeded set).</summary>
        public string? ImageContentType { get; set; }

        /// <summary>Small alpha-preserving PNG thumbnail; the only image bytes shipped on the list DTO (§12).</summary>
        public byte[]? ImageThumbnail { get; set; }

        public ICollection<Destination> Destinations { get; set; } = new List<Destination>();
    }
}
