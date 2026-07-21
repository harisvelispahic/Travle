namespace Travle.Model.Access
{
    /// <summary>Starts the reset flow: the user asks for a code to be emailed to this address.</summary>
    public class ForgotPasswordRequest
    {
        public string Email { get; set; } = string.Empty;
    }
}
