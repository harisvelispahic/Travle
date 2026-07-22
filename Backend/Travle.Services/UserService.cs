using Travle.Model.Constants;
using Travle.Model.Exceptions;
using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Travle.Services.Authorization;
using Travle.Services.Database;
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
        private readonly RecommenderOptions _recommenderOptions;
        private readonly IValidator<UserRegisterRequest> _registerValidator;
        private readonly IValidator<UserUpdateRequest> _updateValidator;
        private readonly IValidator<UserPasswordChangeRequest> _passwordChangeValidator;
        private readonly IValidator<UserSuspendRequest> _suspendValidator;
        private readonly IValidator<UserOnboardingRequest> _onboardingValidator;

        public UserService(
            TravleDbContext dbContext,
            MapsterMapper.IMapper mapper,
            ICryptoService cryptoService,
            IAppAuthorizationService authorization,
            IOptions<RecommenderOptions> recommenderOptions,
            IValidator<UserRegisterRequest> registerValidator,
            IValidator<UserUpdateRequest> updateValidator,
            IValidator<UserPasswordChangeRequest> passwordChangeValidator,
            IValidator<UserSuspendRequest> suspendValidator,
            IValidator<UserOnboardingRequest> onboardingValidator)
            : base(mapper, dbContext)
        {
            _cryptoService = cryptoService;
            _authorization = authorization;
            _recommenderOptions = recommenderOptions.Value;
            _registerValidator = registerValidator;
            _updateValidator = updateValidator;
            _passwordChangeValidator = passwordChangeValidator;
            _suspendValidator = suspendValidator;
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

            if (!string.IsNullOrWhiteSpace(search.Name))
            {
                query = query.Where(u => u.FirstName.Contains(search.Name)
                                      || u.LastName.Contains(search.Name));
            }

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
                CityId = request.CityId,
                PasswordSalt = salt,
                PasswordHash = _cryptoService.GenerateHash(request.Password, salt),
                UserRoles = new List<UserRole> { new() { RoleId = travelerRole.Id } }
            };

            _dbContext.Users.Add(user);
            await _dbContext.SaveChangesAsync();

            return await RequireWithRolesAsync(user.Id);
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

            await _dbContext.SaveChangesAsync();
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

            // Suspending revokes access immediately: drop all of the user's refresh tokens.
            _dbContext.RefreshTokens.RemoveRange(_dbContext.RefreshTokens.Where(rt => rt.UserId == id));

            await _dbContext.SaveChangesAsync();

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

            await _dbContext.SaveChangesAsync();

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

        public async Task<UserResponse?> GetWithRolesByIdAsync(int id)
        {
            var user = await _dbContext.Users
                .AsNoTracking()
                .Include(u => u.UserRoles).ThenInclude(ur => ur.Role)
                .Include(u => u.City)
                .FirstOrDefaultAsync(u => u.Id == id);

            return user is null ? null : _mapper.Map<UserResponse>(user);
        }

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

        // Re-reads the just-mutated user with roles + city so the response DTO is fully populated.
        // This is data loading, not authorization — it stays in the user service.
        private async Task<UserResponse> RequireWithRolesAsync(int id)
            => await GetWithRolesByIdAsync(id) ?? throw new NotFoundException("User", id);
    }
}
