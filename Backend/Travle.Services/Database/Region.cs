namespace Travle.Services.Database
{
    /// <summary>Reference table. A region belongs to a <see cref="Country"/> and groups <see cref="City"/> rows.</summary>
    public class Region : BaseEntity
    {
        public string Name { get; set; } = string.Empty;

        public int CountryId { get; set; }
        public Country Country { get; set; } = null!;

        public ICollection<City> Cities { get; set; } = new List<City>();
    }
}
