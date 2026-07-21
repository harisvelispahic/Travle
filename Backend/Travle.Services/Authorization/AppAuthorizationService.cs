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

        public void EnsureInRole(string role)
        {
            // Ensure authenticated first so an anonymous caller gets a 401, not a 403.
            RequireUserId();

            if (!_currentUser.IsInRole(role))
            {
                throw new ForbiddenException($"This action requires the {role} role.");
            }
        }

        public void EnsureInAnyRole(params string[] roles)
        {
            RequireUserId();

            if (!roles.Any(_currentUser.IsInRole))
            {
                throw new ForbiddenException("You do not have permission to perform this action.");
            }
        }

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
