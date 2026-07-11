namespace Travle.Services;

/// <summary>
/// Provides the authenticated application user for the current request (when available).
/// </summary>
public interface IAuthenticatedUserAccessor
{
    int? GetUserId();

    /// <summary>
    /// Returns whether the current principal is authenticated and has the given application role (JWT Role claim).
    /// </summary>
    bool IsInRole(string role);
}
