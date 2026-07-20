namespace Travle.Services.Database
{
    /// <summary>
    /// Many-to-many link between <see cref="User"/> and <see cref="Role"/>. A bare join table
    /// (composite key <c>(UserId, RoleId)</c>, no surrogate key or timestamps) per 03 §2 / 02 §2b —
    /// it carries no meaningful attributes of its own.
    /// </summary>
    public class UserRole
    {
        public int UserId { get; set; }
        public User User { get; set; } = null!;

        public int RoleId { get; set; }
        public Role Role { get; set; } = null!;
    }
}
