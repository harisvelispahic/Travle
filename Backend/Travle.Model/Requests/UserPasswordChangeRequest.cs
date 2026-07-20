namespace Travle.Model.Requests
{
    /// <summary>
    /// A user changing their own password. The account is taken from the JWT, never the body
    /// (course §J), so there is no Id here; the current password is confirmed (course §I/§4).
    /// </summary>
    public class UserPasswordChangeRequest
    {
        public string CurrentPassword { get; set; } = string.Empty;
        public string NewPassword { get; set; } = string.Empty;
        public string ConfirmNewPassword { get; set; } = string.Empty;
    }
}
