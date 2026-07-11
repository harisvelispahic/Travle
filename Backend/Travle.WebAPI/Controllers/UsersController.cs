using Travle.Model.Access;
using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Travle.Services;
using Travle.WebAPI.Filters;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Travle.WebAPI.Controllers;

[ApiController]
[Route("[controller]")]
public class UsersController : BaseCRUDController<UserResponse, UserSearch, UserInsertRequest, UserUpdateRequest, IUserService>
{
    public UsersController(IUserService userService) : base(userService)
    {
    }

    //[Authorization("Admin")]
    public override Task<PageResult<UserResponse>> GetAll([FromQuery] UserSearch? search)
    {
        return base.GetAll(search);
    }

    //[Authorization]
    [HttpPut("ChangePassword")]
    public async Task<IActionResult> ChangePassword([FromBody] UserPasswordChangeRequest request)
    {
        await _service.ChangePasswordAsync(request);
        return Ok();
    }
}