namespace Travle.Model.Responses
{
    public class CategoryResponse
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;

        /// <summary>
        /// Parent category identifier for hierarchical categories (null for root items).
        /// </summary>
        public int? ParentCategoryId { get; set; }

        public bool IsActive { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime? UpdatedAt { get; set; }
    }
}