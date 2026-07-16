namespace Travle.Services.Database
{
    /// <summary>
    /// A hashed, expiring password-reset code emailed to the user (Dodatak A.3). Technical row —
    /// consumed (<see cref="UsedAt"/>) or expired codes are purged by the scheduler.
    /// </summary>
    public class PasswordResetCode : BaseEntity
    {
        public int UserId { get; set; }
        public User User { get; set; } = null!;

        public string CodeHash { get; set; } = string.Empty;
        public DateTime ExpiresAt { get; set; }
        public DateTime? UsedAt { get; set; }
    }
}
