namespace Travle.Model.Requests
{
    /// <summary>
    /// Toggles a favorite for the JWT user against exactly one target — a destination or a tour. If the
    /// favorite exists it is removed; otherwise it is created. The service rejects a request that sets
    /// both or neither (mirrors the entity's check constraint).
    /// </summary>
    public class FavoriteToggleRequest
    {
        public int? DestinationId { get; set; }
        public int? TourId { get; set; }
    }
}
