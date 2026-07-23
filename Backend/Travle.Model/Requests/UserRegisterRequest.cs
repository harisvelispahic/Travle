namespace Travle.Model.Requests
{
    /// <summary>
    /// Self-service registration. The client supplies only profile data — never a role or any
    /// privileged flag (course §J); the service always assigns the Traveler role.
    /// </summary>
    public class UserRegisterRequest
    {
        public string FirstName { get; set; } = string.Empty;
        public string LastName { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string Username { get; set; } = string.Empty;
        public string Password { get; set; } = string.Empty;
        public string? PhoneNumber { get; set; }
    }
}
