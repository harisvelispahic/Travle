using Travle.Model.Constants;
using Travle.Services.Database;
using Microsoft.EntityFrameworkCore;

namespace Travle.Services.Notifications
{
    /// <summary>
    /// Resolves recipient sets for fan-out notifications — events that go to a role rather than a single
    /// user (e.g. every admin gets the "new item to moderate" nudge). Small queries, called once per event.
    /// </summary>
    internal static class NotificationRecipients
    {
        /// <summary>The user ids of every account holding the Admin role.</summary>
        public static Task<List<int>> AdminUserIdsAsync(TravleDbContext dbContext, CancellationToken cancellationToken = default)
            => dbContext.UserRoles
                .Where(ur => ur.Role.Name == RoleNames.Admin)
                .Select(ur => ur.UserId)
                .Distinct()
                .ToListAsync(cancellationToken);
    }
}
