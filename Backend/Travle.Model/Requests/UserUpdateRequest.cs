using System.ComponentModel.DataAnnotations;

namespace Travle.Model.Requests
{
    public class UserUpdateRequest
    {
        public string? FirstName { get; set; }
        public string? LastName { get; set; }
        public string? Email { get; set; }
        public string? Username { get; set; }
        public string? PhoneNumber { get; set; }
        public bool IsActive { get; set; }
        public string? ProfileImageBase64 { get; set; }
    }
}
