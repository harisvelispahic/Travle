namespace Travle.Model.Constants
{
    /// <summary>
    /// Custom JWT claim types Travle mints beyond the standard set. Kept in one place (no magic
    /// strings) so the token issuer and the validation gate can't drift apart.
    /// </summary>
    public static class TravleClaimTypes
    {
        /// <summary>
        /// The account's <c>SecurityStamp</c> at the moment the token was issued. The JwtBearer
        /// <c>OnTokenValidated</c> gate compares it to the user's current stamp and rejects the token
        /// if they differ — the mechanism that makes stateless access tokens revocable. See
        /// docs/auth-token-invalidation.md.
        /// </summary>
        public const string SecurityStamp = "security_stamp";
    }
}
