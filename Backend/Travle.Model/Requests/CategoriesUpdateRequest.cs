namespace Travle.Model.Requests
{
    public class CategoriesUpdateRequest
    {
        public string Name { get; set; } = string.Empty;
        
        public string Description { get; set; } = string.Empty;
        
        public int? ParentCategoryId { get; set; }
        
        public bool IsActive { get; set; } = true;
    }
}
