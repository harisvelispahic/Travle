namespace Travle.Services.Database
{
    /// <summary>Reference table. Top of the Country → Region → City geographic chain.</summary>
    public class Country : BaseEntity
    {
        public string Name { get; set; } = string.Empty;

        public ICollection<Region> Regions { get; set; } = new List<Region>();
    }
}
