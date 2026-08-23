namespace Travle.Services.Security
{
    /// <summary>
    /// Mints account security stamps in one place. The stamp is the value the JwtBearer
    /// <c>OnTokenValidated</c> gate compares against the token's <c>security_stamp</c> claim, so
    /// <b>rolling it invalidates every access token already issued for that account</b>. Every code path
    /// that must end existing sessions — suspension, role change, password change/reset, logout —
    /// calls <see cref="New"/> rather than repeating the generation inline (DRY, course §8.1).
    /// See docs/auth-token-invalidation.md.
    /// </summary>
    public static class SecurityStamps
    {
        /// <summary>A fresh, opaque stamp. 32 hex characters, so it fits the 64-char column.</summary>
        public static string New() => Guid.NewGuid().ToString("N");
    }
}
