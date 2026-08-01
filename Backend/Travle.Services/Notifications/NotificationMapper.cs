using Travle.Model.Responses;
using Travle.Services.Database;

namespace Travle.Services.Notifications
{
    /// <summary>Maps a <see cref="Notification"/> entity to its response DTO (enum → name in memory).</summary>
    internal static class NotificationMapper
    {
        public static NotificationResponse ToResponse(Notification notification) => new()
        {
            Id = notification.Id,
            UserId = notification.UserId,
            Title = notification.Title,
            Text = notification.Text,
            Type = notification.Type.ToString(),
            RelatedEntityId = notification.RelatedEntityId,
            IsRead = notification.IsRead,
            ReadAt = notification.ReadAt,
            CreatedAt = notification.CreatedAt
        };
    }
}
