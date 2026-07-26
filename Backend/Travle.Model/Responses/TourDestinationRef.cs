namespace Travle.Model.Responses
{
    /// <summary>
    /// One ordered stop of a tour, as shown on the tour detail screen: the destination's name and city,
    /// its coordinates (so the stops can be mapped) and a small thumbnail. The ordering key
    /// (<see cref="SortOrder"/>) is preserved so the itinerary renders in the organizer's intended order.
    /// Full image bytes still come from the destination image endpoint — only the thumbnail travels here.
    /// </summary>
    public class TourDestinationRef
    {
        public int DestinationId { get; set; }

        public string Name { get; set; } = string.Empty;
        public string? CityName { get; set; }

        public double Latitude { get; set; }
        public double Longitude { get; set; }

        public int SortOrder { get; set; }

        public byte[]? Thumbnail { get; set; }
        public string? ThumbnailContentType { get; set; }
    }
}
