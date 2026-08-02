using Travle.Model.Responses;

namespace Travle.Services
{
    /// <summary>
    /// Read-only lookup of the application roles, backing the admin user-management screens (create-user
    /// role picker and grant/revoke). Roles are fixed seeded reference data, never written through the API.
    /// </summary>
    public interface IRoleService
    {
        Task<List<RoleOptionResponse>> GetAllAsync();
    }
}
