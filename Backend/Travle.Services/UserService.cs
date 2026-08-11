using Travle.Model.Constants;
using Travle.Model.Exceptions;
using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Travle.Services.Authorization;
using Travle.Services.Database;
using Travle.Services.Imaging;
using Travle.Services.Notifications;
using Travle.Services.Recommender;
using Travle.Services.Security;
using FluentValidation;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace Travle.Services
{
    public class UserService : BaseReadService<User, UserResponse, UserSearch>, IUserService
    {
        private readonly ICryptoService _cryptoService;
        private readonly IAppAuthorizationService _authorization;
        private readonly IThumbnailGenerator _thumbnailGenerator;
        private readonly RecommenderOptions _recommenderOptions;
        private readonly IRecommendationCache _recommendationCache;
        private readonly INotificationDispatcher _notifications;
        private readonly IUserSecurityStore _securityStore;
        private readonly IValidator<UserRegisterRequest> _registerValidator;
        private readonly IValidator<AdminCreateUserRequest> _createValidator;
        private readonly IValidator<UserUpdateRequest> _updateValidator;
        private readonly IValidator<UserPasswordChangeRequest> _passwordChangeValidator;
        private readonly IValidator<UserSuspendRequest> _suspendValidator;
        private readonly IValidator<UserRoleGrantRequest> _roleGrantValidator;
        private readonly IValidator<UserOnboardingRequest> _onboardingValidator;

        public UserService(
            TravleDbContext dbContext,
            MapsterMapper.IMapper mapper,
            ICryptoService cryptoService,
            IAppAuthorizationService authorization,
            IThumbnailGenerator thumbnailGenerator,
            IOptions<RecommenderOptions> recommenderOptions,
            IRecommendationCache recommendationCache,
            INotificationDispatcher notifications,
            IUserSecurityStore securityStore,
            IValidator<UserRegisterRequest> registerValidator,
            IValidator<AdminCreateUserRequest> createValidator,
            IValidator<UserUpdateRequest> updateValidator,
            IValidator<UserPasswordChangeRequest> passwordChangeValidator,
            IValidator<UserSuspendRequest> suspendValidator,
            IValidator<UserRoleGrantRequest> roleGrantValidator,
            IValidator<UserOnboardingRequest> onboardingValidator)
            : base(mapper, dbContext)
        {
            _cryptoService = cryptoService;
            _authorization = authorization;
            _thumbnailGenerator = thumbnailGenerator;
            _recommenderOptions = recommenderOptions.Value;
            _recommendationCache = recommendationCache;
            _notifications = notifications;
            _securityStore = securityStore;
            _registerValidator = registerValidator;
            _createValidator = createValidator;
            _updateValidator = updateValidator;
            _passwordChangeValidator = passwordChangeValidator;
            _suspendValidator = suspendValidator;
            _roleGrantValidator = roleGrantValidator;
            _onboardingValidator = onboardingValidator;
        }

        protected override IQueryable<User> ApplyFilters(IQueryable<User> query, UserSearch? search)
        {
            if (search is null)
            {
                return query;
            }

            if (!string.IsNullOrWhiteSpace(search.Email))
            {
                query = query.Where(u => u.Email.Contains(search.Email));
            }

            if (!string.IsNullOrWhiteSpace(search.Username))
            {
                query = query.Where(u => u.Username.Contains(search.Username));
            }

            query = query.WhereContains(search.Name, u => u.FirstName, u => u.LastName);

            if (search.IsSuspended.HasValue)
            {
                query = query.Where(u => u.IsSuspended == search.IsSuspended.Value);
            }

            if (!string.IsNullOrWhiteSpace(search.RoleName))
            {
                query = query.Where(u => u.UserRoles.Any(ur => ur.Role.Name == search.RoleName));
            }

            return query;
        }

        // List path: hydrate roles + city so the DTO's Roles/CityName are populated (JOIN, not N+1).
        protected override IQueryable<User> ApplyIncludes(IQueryable<User> query, UserSearch? search)
            => query.Include(u => u.UserRoles).ThenInclude(ur => ur.Role)
                    .Include(u => u.City);

        // Single-entity path (admin GetById): load the same navigations the DTO flattens.
        protected override async Task LoadResponseNavigationsAsync(User entity)
        {
            await _dbContext.Entry(entity).Collection(u => u.UserRoles).Query().Include(ur => ur.Role).LoadAsync();
            await _dbContext.Entry(entity).Reference(u => u.City).LoadAsync();
        }

        /// <summary>
        /// List path (admin user management). Projected by hand (see <see cref="ProjectToResponse"/>) so the
        /// heavy <see cref="User.ProfileImage"/> column is never selected — only the small thumbnail travels
        /// (rule 12 / §8.2). Filter/sort/page reuse the base stages.
        /// </summary>
        public override async Task<PageResult<UserResponse>> GetAllAsync(UserSearch? search = null)
        {
            IQueryable<User> query = _dbContext.Users.AsNoTracking();
            query = ApplyFilters(query, search);

            int? totalCount = null;
            if (search?.IncludeTotalCount ?? false)
            {
                totalCount = await query.CountAsync();
            }

            query = ApplySorting(query, search);
            query = ApplyPaging(query, search);

            var items = await ProjectToResponse(query).ToListAsync();

            return new PageResult<UserResponse> { Items = items, TotalCount = totalCount };
        }

        /// <summary>
        /// The list/self projection: every public field plus the small avatar thumbnail, but never the heavy
        /// full <see cref="User.ProfileImage"/> bytes (rule 12 / §8.2). The full image is loaded only by the
        /// admin detail read (base Mapster path). Shared by the list and the self read (<c>/Access/Me</c>).
        /// </summary>
        private static IQueryable<UserResponse> ProjectToResponse(IQueryable<User> query)
            => query.Select(u => new UserResponse
            {
                Id = u.Id,
                SecurityStamp = u.SecurityStamp,
                FirstName = u.FirstName,
                LastName = u.LastName,
                Email = u.Email,
                Username = u.Username,
                PhoneNumber = u.PhoneNumber,
                Roles = u.UserRoles.Select(ur => ur.Role.Name).ToList(),
                IsSuspended = u.IsSuspended,
                SuspendedAt = u.SuspendedAt,
                SuspensionReason = u.SuspensionReason,
                CityId = u.CityId,
                CityName = u.City != null ? u.City.Name : null,
                IsOnboarded = u.IsOnboarded,
                OnboardingPromptCount = u.OnboardingPromptCount,
                // Thumbnail only — the full ProfileImage bytes are intentionally never selected here.
                ProfileImageThumbnail = u.ProfileImageThumbnail,
                CreatedAt = u.CreatedAt,
                ModifiedAt = u.ModifiedAt
            });

        public async Task<UserResponse> RegisterAsync(UserRegisterRequest request)
        {
            await _registerValidator.ValidateAndThrowAsync(request);

            if (await _dbContext.Users.AnyAsync(u => u.Email == request.Email))
            {
                throw new ConflictException($"Email '{request.Email}' is already in use.");
            }

            if (await _dbContext.Users.AnyAsync(u => u.Username == request.Username))
            {
                throw new ConflictException($"Username '{request.Username}' is already in use.");
            }

            var travelerRole = await _dbContext.Roles.FirstOrDefaultAsync(r => r.Name == RoleNames.Traveler)
                ?? throw new BusinessRuleException("The Traveler role is not configured.");

            var salt = _cryptoService.GenerateSalt();

            var user = new User
            {
                FirstName = request.FirstName,
                LastName = request.LastName,
                Email = request.Email,
                Username = request.Username,
                PhoneNumber = request.PhoneNumber,
                PasswordSalt = salt,
                PasswordHash = _cryptoService.GenerateHash(request.Password, salt),
                UserRoles = new List<UserRole> { new() { RoleId = travelerRole.Id } }
            };

            _dbContext.Users.Add(user);
            await _dbContext.SaveChangesAsync();

            return await RequireWithRolesAsync(user.Id);
        }

        public async Task<UserResponse> CreateAsync(AdminCreateUserRequest request)
        {
            // Admin-only. The controller policy is the first gate; this makes the service its own boundary
            // so the check holds regardless of how the method is reached.
            _authorization.EnsureInRole(RoleNames.Admin);

            await _createValidator.ValidateAndThrowAsync(request);

            if (await _dbContext.Users.AnyAsync(u => u.Email == request.Email))
            {
                throw new ConflictException($"Email '{request.Email}' is already in use.");
            }

            if (await _dbContext.Users.AnyAsync(u => u.Username == request.Username))
            {
                throw new ConflictException($"Username '{request.Username}' is already in use.");
            }

            // Verify every requested role exists so a bad id surfaces as a friendly 400, not an FK failure.
            var roleIds = request.RoleIds.Distinct().ToList();
            if (await _dbContext.Roles.CountAsync(r => roleIds.Contains(r.Id)) != roleIds.Count)
            {
                throw new BusinessRuleException("One or more selected roles do not exist.");
            }

            var salt = _cryptoService.GenerateSalt();

            var user = new User
            {
                FirstName = request.FirstName,
                LastName = request.LastName,
                Email = request.Email,
                Username = request.Username,
                PhoneNumber = request.PhoneNumber,
                PasswordSalt = salt,
                PasswordHash = _cryptoService.GenerateHash(request.Password, salt),
                UserRoles = roleIds.Select(roleId => new UserRole { RoleId = roleId }).ToList()
            };

            _dbContext.Users.Add(user);

            // Account row + welcome notification commit together (two SaveChanges → one transaction, rule 7):
            // the first save assigns the user id the notification is addressed to. The message never carries
            // the password — only the username, so the new user knows how to sign in.
            await using var transaction = await _dbContext.Database.BeginTransactionAsync();
            await _dbContext.SaveChangesAsync();

            _notifications.Enqueue(user.Id, NotificationType.AccountCreated,
                "Welcome to Travle",
                $"An account has been created for you. Sign in with the username '{user.Username}'.",
                relatedEntityId: null, alsoEmail: true);
            await _dbContext.SaveChangesAsync();

            await transaction.CommitAsync();

            return await RequireWithRolesAsync(user.Id);
        }

        public async Task<UserResponse> GrantRoleAsync(int id, UserRoleGrantRequest request)
        {
            _authorization.EnsureInRole(RoleNames.Admin);
            var actorId = _authorization.RequireUserId();

            await _roleGrantValidator.ValidateAndThrowAsync(request);

            var user = await _dbContext.Users
                .Include(u => u.UserRoles)
                .FirstOrDefaultAsync(u => u.Id == id)
                ?? throw new NotFoundException("User", id);

            var role = await _dbContext.Roles.FirstOrDefaultAsync(r => r.Id == request.RoleId)
                ?? throw new BusinessRuleException("The selected role does not exist.");

            if (user.UserRoles.Any(ur => ur.RoleId == role.Id))
            {
                throw new BusinessRuleException($"This user already holds the {role.Name} role.");
            }

            _dbContext.UserRoles.Add(new UserRole { UserId = id, RoleId = role.Id });

            // Bump the stamp so the current access token is rejected on its next request and picks up the
            // new role. Other users are also fully re-logged-in (drop refresh tokens); an admin granting
            // themselves a non-admin role keeps their refresh tokens so their client silently refreshes
            // to the new claims without a visible logout.
            user.SecurityStamp = NewSecurityStamp();
            if (!(id == actorId && role.Name != RoleNames.Admin))
            {
                _dbContext.RefreshTokens.RemoveRange(_dbContext.RefreshTokens.Where(rt => rt.UserId == id));
            }

            _notifications.Enqueue(id, NotificationType.RoleGranted,
                "Role granted",
                $"You have been granted the {role.Name} role.",
                relatedEntityId: null, alsoEmail: true);

            // Role grant + stamp bump + token revoke + notification in one SaveChanges = one implicit transaction.
            await _dbContext.SaveChangesAsync();
            _securityStore.Invalidate(id);

            return await RequireWithRolesAsync(id);
        }

        public async Task<UserResponse> RevokeRoleAsync(int id, int roleId)
        {
            _authorization.EnsureInRole(RoleNames.Admin);
            var adminId = _authorization.RequireUserId();

            var user = await _dbContext.Users
                .Include(u => u.UserRoles).ThenInclude(ur => ur.Role)
                .FirstOrDefaultAsync(u => u.Id == id)
                ?? throw new NotFoundException("User", id);

            var userRole = user.UserRoles.FirstOrDefault(ur => ur.RoleId == roleId)
                ?? throw new BusinessRuleException("This user does not hold that role.");

            var roleName = userRole.Role.Name;

            // An admin cannot strip Admin from their own account (self-lockout prevention).
            if (roleName == RoleNames.Admin && id == adminId)
            {
                throw new BusinessRuleException("You cannot remove the Admin role from your own account.");
            }

            // Never remove the last remaining Admin — the platform must always keep at least one.
            if (roleName == RoleNames.Admin
                && await _dbContext.UserRoles.CountAsync(ur => ur.Role.Name == RoleNames.Admin) <= 1)
            {
                throw new BusinessRuleException("You cannot remove the last remaining Admin.");
            }

            _dbContext.UserRoles.Remove(userRole);

            // Same rationale as granting: bump the stamp so the current access token is rejected and re-minted
            // without the role. Other users are fully re-logged-in (drop refresh tokens); an admin removing a
            // non-admin role from their own account keeps their refresh tokens so their client silently
            // refreshes to the reduced claims without a visible logout.
            user.SecurityStamp = NewSecurityStamp();
            if (!(id == adminId && roleName != RoleNames.Admin))
            {
                _dbContext.RefreshTokens.RemoveRange(_dbContext.RefreshTokens.Where(rt => rt.UserId == id));
            }

            _notifications.Enqueue(id, NotificationType.RoleRevoked,
                "Role removed",
                $"Your {roleName} role has been removed.",
                relatedEntityId: null, alsoEmail: true);

            await _dbContext.SaveChangesAsync();
            _securityStore.Invalidate(id);

            return await RequireWithRolesAsync(id);
        }

        public async Task<UserResponse> UpdateProfileAsync(int id, UserUpdateRequest request)
        {
            _authorization.EnsureSelfOrAdmin(id, "profile");

            await _updateValidator.ValidateAndThrowAsync(request);

            // Trust the bytes, not the declared type: a profile image must actually be a JPEG/PNG by its
            // magic bytes (course §I). Shape (type present, allowed, size) is covered by the validator.
            if (request.ProfileImage is { Length: > 0 }
                && !FileSignatureValidator.IsValid(request.ProfileImage, request.ProfileImageContentType, FileSignatureValidator.ImageContentTypes))
            {
                throw new BusinessRuleException("The profile image must be a valid JPEG or PNG file.");
            }

            var user = await _dbContext.Users.FirstOrDefaultAsync(u => u.Id == id)
                ?? throw new NotFoundException("User", id);

            if (request.Email is not null && await _dbContext.Users.AnyAsync(u => u.Email == request.Email && u.Id != id))
            {
                throw new ConflictException($"Email '{request.Email}' is already in use.");
            }

            if (request.Username is not null && await _dbContext.Users.AnyAsync(u => u.Username == request.Username && u.Id != id))
            {
                throw new ConflictException($"Username '{request.Username}' is already in use.");
            }

            // Null members are ignored (Mapster IgnoreNullValues) so unspecified fields keep their value.
            _mapper.Map(request, user);

            // A newly uploaded image gets a fresh server-side thumbnail — the only image bytes that ever
            // travel back to a client (rule 12 / §8.2). Generated from the validated bytes, never client-supplied.
            if (request.ProfileImage is { Length: > 0 })
            {
                var (thumbnail, _) = await _thumbnailGenerator.GenerateThumbnailAsync(request.ProfileImage);
                user.ProfileImageThumbnail = thumbnail;
            }

            await _dbContext.SaveChangesAsync();

            return await RequireWithRolesAsync(id);
        }

        public async Task ChangePasswordAsync(UserPasswordChangeRequest request)
        {
            var userId = _authorization.RequireUserId();

            await _passwordChangeValidator.ValidateAndThrowAsync(request);

            var user = await _dbContext.Users.FirstOrDefaultAsync(u => u.Id == userId)
                ?? throw new NotFoundException("User", userId);

            if (!_cryptoService.Verify(user.PasswordHash, user.PasswordSalt, request.CurrentPassword))
            {
                throw new BusinessRuleException("Current password is incorrect.");
            }

            user.PasswordSalt = _cryptoService.GenerateSalt();
            user.PasswordHash = _cryptoService.GenerateHash(request.NewPassword, user.PasswordSalt);

            // A password change ends every session: bump the stamp (rejects existing access tokens) and
            // drop the refresh tokens, so the user signs in again with the new password.
            user.SecurityStamp = NewSecurityStamp();
            _dbContext.RefreshTokens.RemoveRange(_dbContext.RefreshTokens.Where(rt => rt.UserId == userId));

            await _dbContext.SaveChangesAsync();
            _securityStore.Invalidate(userId);
        }

        public async Task<UserResponse> SuspendAsync(int id, UserSuspendRequest request)
        {
            // Admin-only. The controller policy is the first gate; this makes the service its own
            // boundary so the check holds regardless of how the method is reached.
            _authorization.EnsureInRole(RoleNames.Admin);

            await _suspendValidator.ValidateAndThrowAsync(request);

            var adminId = _authorization.RequireUserId();

            var user = await _dbContext.Users.FirstOrDefaultAsync(u => u.Id == id)
                ?? throw new NotFoundException("User", id);

            if (user.Id == adminId)
            {
                throw new BusinessRuleException("You cannot suspend your own account.");
            }

            if (user.IsSuspended)
            {
                throw new BusinessRuleException("This user is already suspended.");
            }

            user.IsSuspended = true;
            user.SuspendedAt = DateTime.UtcNow;
            user.SuspendedByUserId = adminId;
            user.SuspensionReason = request.Reason;

            // Suspending revokes access immediately: bump the security stamp (so the current access token
            // is rejected on its next request — the gate also rejects on the IsSuspended flag) and drop
            // all of the user's refresh tokens so they cannot mint a new one.
            user.SecurityStamp = NewSecurityStamp();
            _dbContext.RefreshTokens.RemoveRange(_dbContext.RefreshTokens.Where(rt => rt.UserId == id));

            // The suspended user learns why by email (their session is being revoked, so email is the channel
            // that reaches them); the in-app row is also kept for transparency if they are later reinstated.
            // Staged so it commits with the suspension; the email fires on the post-commit flush.
            _notifications.Enqueue(id, NotificationType.AccountSuspended,
                "Account suspended",
                $"Your Travle account has been suspended. Reason: {request.Reason}",
                relatedEntityId: null, alsoEmail: true);

            await _dbContext.SaveChangesAsync();
            _securityStore.Invalidate(id);

            return await RequireWithRolesAsync(id);
        }

        public async Task<UserResponse> UnsuspendAsync(int id)
        {
            _authorization.EnsureInRole(RoleNames.Admin);

            var user = await _dbContext.Users.FirstOrDefaultAsync(u => u.Id == id)
                ?? throw new NotFoundException("User", id);

            if (!user.IsSuspended)
            {
                throw new BusinessRuleException("This user is not suspended.");
            }

            user.IsSuspended = false;
            user.SuspendedAt = null;
            user.SuspendedByUserId = null;
            user.SuspensionReason = null;

            // Roll the stamp for consistency (the account had no live sessions while suspended, so there
            // is nothing to invalidate) and refresh the cached state.
            user.SecurityStamp = NewSecurityStamp();

            await _dbContext.SaveChangesAsync();
            _securityStore.Invalidate(id);

            return await RequireWithRolesAsync(id);
        }

        public async Task<UserResponse?> ValidateCredentialsAsync(string username, string password)
        {
            var user = await _dbContext.Users
                .AsNoTracking()
                .Include(u => u.UserRoles).ThenInclude(ur => ur.Role)
                .FirstOrDefaultAsync(u => u.Username == username);

            // Same negative result for unknown user and wrong password (no username enumeration).
            if (user is null || !_cryptoService.Verify(user.PasswordHash, user.PasswordSalt, password))
            {
                return null;
            }

            return _mapper.Map<UserResponse>(user);
        }

        // Self/roles read (e.g. /Access/Me and the response after every profile mutation). Uses the shared
        // projection so it ships the avatar thumbnail but never the heavy full image — the self screens only
        // ever render the small avatar (rule 12 / §8.2).
        public async Task<UserResponse?> GetWithRolesByIdAsync(int id)
            => await ProjectToResponse(_dbContext.Users.AsNoTracking().Where(u => u.Id == id))
                   .FirstOrDefaultAsync();

        public async Task<UserResponse> CompleteOnboardingAsync(UserOnboardingRequest request)
        {
            // Onboarding is a traveler-only, self-scoped action. Mirror the controller's TravelerOnly
            // policy here so the service stays its own authorization boundary.
            _authorization.EnsureInRole(RoleNames.Traveler);
            var userId = _authorization.RequireUserId();
            await _onboardingValidator.ValidateAndThrowAsync(request);

            var user = await _dbContext.Users.FirstOrDefaultAsync(u => u.Id == userId)
                ?? throw new NotFoundException("User", userId);

            var categoryIds = (request.CategoryIds ?? new List<int>()).Distinct().ToList();
            var tagIds = (request.TagIds ?? new List<int>()).Distinct().ToList();

            // Idempotent: the per-display prompt cap may have already set IsOnboarded before the user
            // finally picks interests, so completing stays allowed — but never duplicate the interests.
            var alreadyRecorded = await _dbContext.UserInteractions
                .AnyAsync(i => i.UserId == userId && i.InteractionType == InteractionType.OnboardingInterest);

            if (!alreadyRecorded)
            {
                // Verify the picks exist so a bad id surfaces as a friendly 400, not an FK failure.
                if (categoryIds.Count > 0
                    && await _dbContext.DestinationCategories.CountAsync(c => categoryIds.Contains(c.Id)) != categoryIds.Count)
                {
                    throw new BusinessRuleException("One or more selected categories do not exist.");
                }

                if (tagIds.Count > 0
                    && await _dbContext.Tags.CountAsync(t => tagIds.Contains(t.Id)) != tagIds.Count)
                {
                    throw new BusinessRuleException("One or more selected tags do not exist.");
                }

                // One OnboardingInterest row per pick (weight from RecommenderOptions, no DestinationId — 04 §2/§3).
                foreach (var categoryId in categoryIds)
                {
                    _dbContext.UserInteractions.Add(new UserInteraction
                    {
                        UserId = userId,
                        InteractionType = InteractionType.OnboardingInterest,
                        Weight = _recommenderOptions.Weights.OnboardingInterest,
                        CategoryId = categoryId
                    });
                }

                foreach (var tagId in tagIds)
                {
                    _dbContext.UserInteractions.Add(new UserInteraction
                    {
                        UserId = userId,
                        InteractionType = InteractionType.OnboardingInterest,
                        Weight = _recommenderOptions.Weights.OnboardingInterest,
                        TagId = tagId
                    });
                }
            }

            user.IsOnboarded = true;

            // Interactions + the flag in one SaveChanges → a single transaction.
            await _dbContext.SaveChangesAsync();

            // Onboarding picks are strong signals → drop the user's cached recommendations (04 §4).
            _recommendationCache.InvalidateUser(userId);

            return await RequireWithRolesAsync(userId);
        }

        public async Task<UserResponse> RegisterOnboardingPromptAsync()
        {
            _authorization.EnsureInRole(RoleNames.Traveler);
            var userId = _authorization.RequireUserId();

            var user = await _dbContext.Users.FirstOrDefaultAsync(u => u.Id == userId)
                ?? throw new NotFoundException("User", userId);

            // Count each display; once the cap is reached, mark onboarded so it stops appearing even if
            // the user never picks interests. No-op once already onboarded.
            if (!user.IsOnboarded)
            {
                user.OnboardingPromptCount += 1;
                if (user.OnboardingPromptCount >= _recommenderOptions.MaxOnboardingPrompts)
                {
                    user.IsOnboarded = true;
                }
                await _dbContext.SaveChangesAsync();
            }

            return await RequireWithRolesAsync(userId);
        }

        /// <summary>
        /// Ends every session server-side (logout): rolls the security stamp — so all outstanding access
        /// tokens are rejected on their next request — and drops the refresh tokens, in a single save.
        /// The in-service auth-change methods (suspend, role change, password change) roll the stamp inline
        /// as part of their own SaveChanges instead of calling this.
        /// </summary>
        public async Task InvalidateAllSessionsAsync(int userId)
        {
            var user = await _dbContext.Users.FirstOrDefaultAsync(u => u.Id == userId)
                ?? throw new NotFoundException("User", userId);

            user.SecurityStamp = NewSecurityStamp();
            _dbContext.RefreshTokens.RemoveRange(_dbContext.RefreshTokens.Where(rt => rt.UserId == userId));
            await _dbContext.SaveChangesAsync();
            _securityStore.Invalidate(userId);
        }

        private static string NewSecurityStamp() => Guid.NewGuid().ToString("N");

        // Re-reads the just-mutated user with roles + city so the response DTO is fully populated.
        // This is data loading, not authorization — it stays in the user service.
        private async Task<UserResponse> RequireWithRolesAsync(int id)
            => await GetWithRolesByIdAsync(id) ?? throw new NotFoundException("User", id);
    }
}
