namespace Travle.Services.Database
{
    /// <summary>
    /// An in-app notification for a user, pushed over SignalR on insert. <see cref="RelatedEntityId"/>
    /// is an optional deep-link target (e.g. the booking id) interpreted per <see cref="Type"/>.
    /// Owner may clear their own; cascades from the user.
    /// </summary>
    public class Notification : BaseEntity
    {
        public int UserId { get; set; }
        public User User { get; set; } = null!;

        public string Title { get; set; } = string.Empty;
        public string Text { get; set; } = string.Empty;
        public NotificationType Type { get; set; }

        public bool IsRead { get; set; }
        public DateTime? ReadAt { get; set; }

        public int? RelatedEntityId { get; set; }
    }
}
