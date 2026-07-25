namespace Travle.Model.Responses
{
    /// <summary>
    /// Metadata for one of a destination's images — never the bytes. The full image is fetched from the
    /// dedicated endpoint (<c>GET /Destinations/{destinationId}/images/{id}</c>) so list/detail payloads
    /// stay light (§8.2). <see cref="SortOrder"/> gives the gallery/edit-grid its order.
    /// </summary>
    public class DestinationImageResponse
    {
        public int Id { get; set; }
        public string ContentType { get; set; } = string.Empty;
        public int SortOrder { get; set; }
    }
}
