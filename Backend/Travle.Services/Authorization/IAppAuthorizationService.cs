namespace Travle.Services.Authorization
{
    /// <summary>
    /// Imperative authorization guards for service-level checks that endpoint policies can't express
    /// — chiefly resource ownership ("this booking is mine"). Keeps auth reasoning out of the domain
    /// services (they call an <c>Ensure…</c> and carry on). Built on
    /// <see cref="IAuthenticatedUserAccessor"/>; throws <c>Travle</c> exceptions the middleware maps.
    /// Add further guards (EnsureAdmin, EnsureOwnerOrRole, …) as the endpoints that need them arrive.
    /// </summary>
    public interface IAppAuthorizationService
    {
        /// <summary>Returns the current user's id, or throws <c>UnauthorizedException</c> if unauthenticated.</summary>
        int RequireUserId();

        /// <summary>
        /// Throws unless the caller is the resource owner or an Admin. <paramref name="resourceName"/>
        /// tailors the forbidden message (e.g. "profile").
        /// </summary>
        void EnsureSelfOrAdmin(int resourceOwnerId, string resourceName = "resource");
    }
}
