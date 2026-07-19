namespace Travle.Model.Responses
{
    public class CityResponse
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public int RegionId { get; set; }
        /// <summary>Flattened from Region.Name by Mapster when the parent is included.</summary>
        public string? RegionName { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime? ModifiedAt { get; set; }
    }
}
