namespace Travle.Model.Responses
{
    public class UserSensitveResponse : UserResponse
    {
        public string PasswordHash { get; set; } = string.Empty;
        public string PasswordSalt { get; set; } = string.Empty;
    }
}
