using Travle.Model.Access;

namespace Travle.Services
{
    public interface IPasswordResetService
    {
        /// <summary>
        /// Issues a reset code (stored hashed) and enqueues the email. Returns normally whether or not
        /// the address is registered, so the endpoint can't be used to discover accounts.
        /// </summary>
        Task RequestResetAsync(ForgotPasswordRequest request, CancellationToken cancellationToken = default);

        /// <summary>Verifies the code and sets the new password, revoking all of the user's sessions.</summary>
        Task ResetPasswordAsync(ResetPasswordRequest request);
    }
}
