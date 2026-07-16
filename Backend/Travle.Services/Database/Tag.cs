namespace Travle.Services.Database
{
    /// <summary>Reference table. Free-form destination labels (m2m via <see cref="DestinationTag"/>); a recommender feature.</summary>
    public class Tag : BaseEntity
    {
        public string Name { get; set; } = string.Empty;

        public ICollection<DestinationTag> DestinationTags { get; set; } = new List<DestinationTag>();
    }
}
