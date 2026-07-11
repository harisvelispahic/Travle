using System.ComponentModel.DataAnnotations;

namespace Travle.Model.Requests
{
    public class CategoriesInsertRequest
    {
        //[Required(ErrorMessage = "Name is required.")]
        //[MaxLength(100, ErrorMessage = "Name cannot exceed 100 characters.")]
        public string Name { get; set; } = string.Empty;

        //[MaxLength(100, ErrorMessage = "Name cannot exceed 100 characters.")]
        public string Description { get; set; } = string.Empty;
        
        public int? ParentCategoryId { get; set; }
        
        public bool IsActive { get; set; } = true;
    }
}
