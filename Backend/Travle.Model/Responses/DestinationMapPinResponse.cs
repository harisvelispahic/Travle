namespace Travle.Model.Responses
{
    /// <summary>
    /// The deliberately light shape returned by the map-browse endpoint: just enough to drop a marker and
    /// render its tap-through mini card — id, name, coordinates, category name, average rating, and the
    /// primary thumbnail. No description, tags, images metadata, or full image bytes travel here (the map
    /// may return many markers at once, so it stays as small as the list cards do — §8.2 / rule 12). The
    /// full detail is fetched from <c>GET /Destinations/{id}</c> when a marker's card is opened.
    /// </summary>
    public class DestinationMapPinResponse
    {
        public int Id { get; set; }

        public string Name { get; set; } = string.Empty;

        public double Latitude { get; set; }
        public double Longitude { get; set; }

        public string? CategoryName { get; set; }

        public double AverageRating { get; set; }

        /// <summary>The primary image's small thumbnail bytes for the marker's mini card (null when the destination has no image).</summary>
        public byte[]? PrimaryThumbnail { get; set; }
        public string? PrimaryThumbnailContentType { get; set; }
    }
}
