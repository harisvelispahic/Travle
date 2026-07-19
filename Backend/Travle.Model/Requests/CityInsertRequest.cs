namespace Travle.Model.Requests
{
    public class CityInsertRequest
    {
        public string Name { get; set; } = string.Empty;
        public int RegionId { get; set; }
    }
}
