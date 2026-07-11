using Travle.Model.Access;
using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;

namespace Travle.Services
{
    public interface IUserService : IBaseCRUDService<UserResponse, UserSearch, UserInsertRequest, UserUpdateRequest>
    {
        Task<UserSensitveResponse?> GetByUsernameAsync(string username);
        Task<UserResponse?> GetWithRoleByIdAsync(int id);
        Task ChangePasswordAsync(UserPasswordChangeRequest request);
    }
}
