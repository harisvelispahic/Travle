namespace Travle.Model.Requests
{
    public class RegionUpdateRequest
    {
        public string Name { get; set; } = string.Empty;
        public int CountryId { get; set; }
    }
}
