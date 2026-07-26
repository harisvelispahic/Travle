namespace Travle.Model.Requests
{
    /// <summary>
    /// Edit of an existing tour by its organizer (or an admin). Content only — activation state is
    /// toggled through the dedicated deactivate/activate endpoints, and the organizer is never
    /// reassigned. <see cref="DestinationIds"/> is the full desired itinerary (the list order is the
    /// new <c>SortOrder</c>); the service reconciles stops against it. Changing
    /// <see cref="DurationMinutes"/> affects only schedules created afterwards — existing slots keep the
    /// end time they were published with.
    /// </summary>
    public class TourUpdateRequest
    {
        public string Name { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;

        public int DurationMinutes { get; set; }
        public decimal PricePerPerson { get; set; }

        public int Capacity { get; set; }

        public int TourTypeId { get; set; }

        public List<int> DestinationIds { get; set; } = new List<int>();
    }
}
