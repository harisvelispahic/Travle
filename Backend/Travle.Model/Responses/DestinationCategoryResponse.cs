namespace Travle.Model.Responses
{
    public class DestinationCategoryResponse
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;

        /// <summary>Short blurb shown on the onboarding category cards; null when unset.</summary>
        public string? Description { get; set; }

        /// <summary>Small PNG thumbnail for the onboarding grid / admin list. The full image is served by the
        /// dedicated <c>GET /DestinationCategories/{id}/image</c> endpoint, never on this list DTO (§12).</summary>
        public byte[]? ImageThumbnail { get; set; }

        public DateTime CreatedAt { get; set; }
        public DateTime? ModifiedAt { get; set; }
    }
}
