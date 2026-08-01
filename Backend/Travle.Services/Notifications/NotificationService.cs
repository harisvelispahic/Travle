using Travle.Model.Exceptions;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Travle.Services.Authorization;
using Travle.Services.Database;
using Microsoft.EntityFrameworkCore;

namespace Travle.Services.Notifications
{
    /// <summary>
    /// Read/manage service for the current user's notifications. Every method scopes to the JWT user id, so
    /// a caller can only ever see or change their own notifications (course §J). Reads are DB-side filtered,
    /// sorted and paged (never pulled into memory to filter).
    /// </summary>
    public sealed class NotificationService : INotificationService
    {
        private const int MaxPageSize = 100;
        private const int DefaultPageSize = 20;

        private readonly TravleDbContext _dbContext;
        private readonly IAppAuthorizationService _authorization;

        public NotificationService(TravleDbContext dbContext, IAppAuthorizationService authorization)
        {
            _dbContext = dbContext;
            _authorization = authorization;
        }

        public async Task<PageResult<NotificationResponse>> GetMineAsync(NotificationSearch? search)
        {
            var userId = _authorization.RequireUserId();
            search ??= new NotificationSearch();

            var query = _dbContext.Notifications.AsNoTracking().Where(n => n.UserId == userId);

            if (search.IsRead.HasValue)
            {
                query = query.Where(n => n.IsRead == search.IsRead.Value);
            }
            if (search.Type.HasValue)
            {
                var type = (NotificationType)search.Type.Value;
                query = query.Where(n => n.Type == type);
            }

            int? totalCount = null;
            if (search.IncludeTotalCount ?? false)
            {
                totalCount = await query.CountAsync();
            }

            query = query.OrderByDescending(n => n.CreatedAt).ThenByDescending(n => n.Id);
            query = Paginate(query, search);

            var entities = await query.ToListAsync();
            var items = entities.Select(NotificationMapper.ToResponse).ToList();

            return new PageResult<NotificationResponse> { Items = items, TotalCount = totalCount };
        }

        public async Task<int> GetUnreadCountAsync()
        {
            var userId = _authorization.RequireUserId();
            return await _dbContext.Notifications.CountAsync(n => n.UserId == userId && !n.IsRead);
        }

        public async Task<NotificationResponse> MarkReadAsync(int id)
        {
            var userId = _authorization.RequireUserId();

            // Scoping the lookup to the owner means another user's id (or a non-existent one) is a 404, not a leak.
            var notification = await _dbContext.Notifications.FirstOrDefaultAsync(n => n.Id == id && n.UserId == userId)
                ?? throw new NotFoundException("Notification", id);

            if (!notification.IsRead)
            {
                notification.IsRead = true;
                notification.ReadAt = DateTime.UtcNow;
                await _dbContext.SaveChangesAsync();
            }

            return NotificationMapper.ToResponse(notification);
        }

        public async Task MarkAllReadAsync()
        {
            var userId = _authorization.RequireUserId();
            var now = DateTime.UtcNow;

            await _dbContext.Notifications
                .Where(n => n.UserId == userId && !n.IsRead)
                .ExecuteUpdateAsync(set => set
                    .SetProperty(n => n.IsRead, true)
                    .SetProperty(n => n.ReadAt, now));
        }

        // Local paging with the same MaxPageSize clamp as the read base, so the list can never be unbounded.
        private static IQueryable<Notification> Paginate(IQueryable<Notification> query, BaseSearchObject search)
        {
            var page = search.Page is int p && p > 0 ? p : 1;

            var pageSize = search.PageSize ?? DefaultPageSize;
            if (pageSize < 1)
            {
                pageSize = DefaultPageSize;
            }
            if (pageSize > MaxPageSize)
            {
                pageSize = MaxPageSize;
            }

            return query.Skip((page - 1) * pageSize).Take(pageSize);
        }
    }
}
