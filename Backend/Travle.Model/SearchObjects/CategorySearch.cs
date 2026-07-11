namespace Travle.Model.SearchObjects
{
    public class CategorySearchObject : BaseSearchObject
    {
        /// <summary>
        /// Substring to match against the category name (case-insensitive).
        /// </summary>
        public string? Name { get; set; }

        /// <summary>
        /// Filter categories by their parent category id (useful for retrieving immediate children).
        /// </summary>
        public int? ParentCategoryId { get; set; }
    }
}