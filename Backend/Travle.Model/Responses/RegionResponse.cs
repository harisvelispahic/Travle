namespace Travle.Model.Responses
{
    public class RegionResponse
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public int CountryId { get; set; }
        /// <summary>Flattened from Country.Name by Mapster when the parent is included.</summary>
        public string? CountryName { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime? ModifiedAt { get; set; }
    }
}
