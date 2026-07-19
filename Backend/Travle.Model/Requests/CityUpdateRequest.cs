namespace Travle.Model.Requests
{
    public class CityUpdateRequest
    {
        public string Name { get; set; } = string.Empty;
        public int RegionId { get; set; }
    }
}
