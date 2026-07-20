using Travle.Model.Constants;
using Travle.Model.Exceptions;

namespace Travle.Services.Authorization
{
    public sealed class AppAuthorizationService : IAppAuthorizationService
    {
        private readonly IAuthenticatedUserAccessor _currentUser;

        public AppAuthorizationService(IAuthenticatedUserAccessor currentUser)
        {
            _currentUser = currentUser;
        }

        public int RequireUserId()
            => _currentUser.GetUserId() ?? throw new UnauthorizedException("You must be signed in.");

        public void EnsureSelfOrAdmin(int resourceOwnerId, string resourceName = "resource")
        {
            var callerId = RequireUserId();

            if (callerId != resourceOwnerId && !_currentUser.IsInRole(RoleNames.Admin))
            {
                throw new ForbiddenException($"You can only modify your own {resourceName}.");
            }
        }
    }
}
