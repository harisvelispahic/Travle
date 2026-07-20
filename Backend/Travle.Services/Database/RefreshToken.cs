namespace Travle.Services.Database
{
    /// <summary>
    /// A stored refresh token. The raw token is returned to the client once and never persisted —
    /// only its SHA-256 hash lives here (so a DB leak can't be replayed). Rotation on refresh marks
    /// the used token <see cref="IsRevoked"/>; logout and suspension delete all of a user's tokens.
    /// </summary>
    public class RefreshToken : BaseEntity
    {
        public string TokenHash { get; set; } = string.Empty;

        public DateTime ExpiresAt { get; set; }

        public bool IsRevoked { get; set; }
        public DateTime? RevokedAt { get; set; }

        public int UserId { get; set; }
        public User User { get; set; } = null!;
    }
}
