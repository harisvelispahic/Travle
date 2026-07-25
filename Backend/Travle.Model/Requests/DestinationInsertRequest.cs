namespace Travle.Model.Requests
{
    /// <summary>
    /// A curator/organizer's destination submission. The submitter is taken from the JWT (never the
    /// client) and the destination always starts <c>Pending</c> — neither is accepted here. Category,
    /// city and tags are FK ids resolved server-side; coordinates are entered directly for now (a map
    /// picker replaces the manual fields later — see 07 §8).
    /// </summary>
    public class DestinationInsertRequest
    {
        public string Name { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;

        public int CategoryId { get; set; }
        public int CityId { get; set; }

        public double Latitude { get; set; }
        public double Longitude { get; set; }

        public List<int> TagIds { get; set; } = new List<int>();
        public List<DestinationImageRequest> Images { get; set; } = new List<DestinationImageRequest>();
    }
}
