namespace Travle.Model.Requests
{
    public class RegionInsertRequest
    {
        public string Name { get; set; } = string.Empty;
        public int CountryId { get; set; }
    }
}
