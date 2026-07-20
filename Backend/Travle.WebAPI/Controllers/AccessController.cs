using Travle.Model.Access;
using Travle.Model.Exceptions;
using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Services;
using Travle.Services.Authorization;
using Travle.WebAPI.Authorization;
using Travle.WebAPI.Services.AccessManager;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Travle.WebAPI.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class AccessController : ControllerBase
    {
        private readonly IAccessManager _accessManager;
        private readonly IUserService _userService;
        private readonly IAppAuthorizationService _authorization;

        public AccessController(
            IAccessManager accessManager,
            IUserService userService,
            IAppAuthorizationService authorization)
        {
            _accessManager = accessManager;
            _userService = userService;
            _authorization = authorization;
        }

        [AllowAnonymous]
        [HttpPost("Login")]
        public async Task<ActionResult<UserLoginResponse>> Login([FromBody] UserLoginRequest request)
            => Ok(await _accessManager.LoginAsync(request));

        [AllowAnonymous]
        [HttpPost("Register")]
        public async Task<ActionResult<UserResponse>> Register([FromBody] UserRegisterRequest request)
            => Ok(await _userService.RegisterAsync(request));

        // Anonymous by design: the caller's access token has expired; the refresh token authenticates itself.
        [AllowAnonymous]
        [HttpPost("RefreshToken")]
        public async Task<ActionResult<UserLoginResponse>> RefreshToken([FromBody] RefreshAccessTokenRequest request)
            => Ok(await _accessManager.RefreshAsync(request));

        [Authorize(Policy = AuthPolicies.Authenticated)]
        [HttpPost("Logout")]
        public async Task<IActionResult> Logout()
        {
            await _accessManager.LogoutAsync(_authorization.RequireUserId());
            return NoContent();
        }

        [Authorize(Policy = AuthPolicies.Authenticated)]
        [HttpGet("Me")]
        public async Task<ActionResult<UserResponse>> Me()
        {
            var userId = _authorization.RequireUserId();
            var user = await _userService.GetWithRolesByIdAsync(userId)
                ?? throw new NotFoundException("User", userId);
            return Ok(user);
        }
    }
}
