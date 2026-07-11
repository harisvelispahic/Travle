namespace Travle.Model.Requests
{
    public class UserPasswordChangeRequest
    {
        public int Id { get; set; }
        public string Password { get; set; } = null!;
        public string NewPassword { get; set; } = null!;
        public string ConfirmNewPassword { get; set; } = null!;
    }
}
