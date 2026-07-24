using Travle.Model.Constants;
using Travle.Model.Exceptions;
using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Travle.Services.Authorization;
using Travle.Services.Database;
using Travle.Services.Security;
using FluentValidation;
using Microsoft.EntityFrameworkCore;

namespace Travle.Services
{
    public class RoleApplicationService
        : BaseReadService<RoleApplication, RoleApplicationResponse, RoleApplicationSearch>,
          IRoleApplicationService
    {
        private readonly IAppAuthorizationService _authorization;
        private readonly IValidator<RoleApplicationSubmitRequest> _submitValidator;
        private readonly IValidator<RoleApplicationRejectRequest> _rejectValidator;

        public RoleApplicationService(
            TravleDbContext dbContext,
            MapsterMapper.IMapper mapper,
            IAppAuthorizationService authorization,
            IValidator<RoleApplicationSubmitRequest> submitValidator,
            IValidator<RoleApplicationRejectRequest> rejectValidator)
            : base(mapper, dbContext)
        {
            _authorization = authorization;
            _submitValidator = submitValidator;
            _rejectValidator = rejectValidator;
        }

        protected override IQueryable<RoleApplication> ApplyFilters(IQueryable<RoleApplication> query, RoleApplicationSearch? search)
        {
            if (search is null)
            {
                return query;
            }

            if (search.Status.HasValue)
            {
                var status = (RoleApplicationStatus)search.Status.Value;
                query = query.Where(a => a.Status == status);
            }

            if (search.RoleId.HasValue)
            {
                query = query.Where(a => a.RoleId == search.RoleId.Value);
            }

            if (search.UserId.HasValue)
            {
                query = query.Where(a => a.UserId == search.UserId.Value);
            }

            return query;
        }

        // List path: JOIN the applicant, role, region and decider so the DTO's flattened names populate.
        protected override IQueryable<RoleApplication> ApplyIncludes(IQueryable<RoleApplication> query, RoleApplicationSearch? search)
            => query.Include(a => a.User)
                    .Include(a => a.Role)
                    .Include(a => a.Region)
                    .Include(a => a.DecidedByUser);

        // Detail read is owner-or-admin (the base has no ownership notion), so it is overridden here.
        public override async Task<RoleApplicationResponse> GetByIdAsync(int id)
        {
            var application = await LoadWithNavigationsAsync(id);
            _authorization.EnsureSelfOrAdmin(application.UserId, "application");
            return _mapper.Map<RoleApplicationResponse>(application);
        }

        public async Task<PageResult<RoleApplicationResponse>> GetMineAsync(RoleApplicationSearch? search)
        {
            var userId = _authorization.RequireUserId();
            search ??= new RoleApplicationSearch();
            // Force ownership scoping: a caller can never widen this to someone else's applications.
            search.UserId = userId;
            return await GetAllAsync(search);
        }

        public async Task<List<RoleOptionResponse>> GetApplicableRolesAsync()
        {
            var userId = _authorization.RequireUserId();

            var applicableNames = new[] { RoleNames.Curator, RoleNames.Organizer };

            // Roles the user already holds, and roles with a still-pending application — both exclude a
            // role from the applicable set (can't re-apply while pending, or for one you already have).
            var heldRoleIds = _dbContext.UserRoles
                .Where(ur => ur.UserId == userId)
                .Select(ur => ur.RoleId);
            var pendingRoleIds = _dbContext.RoleApplications
                .Where(a => a.UserId == userId && a.Status == RoleApplicationStatus.Pending)
                .Select(a => a.RoleId);

            return await _dbContext.Roles
                .Where(r => applicableNames.Contains(r.Name)
                            && !heldRoleIds.Contains(r.Id)
                            && !pendingRoleIds.Contains(r.Id))
                .OrderBy(r => r.Name)
                .Select(r => new RoleOptionResponse { Id = r.Id, Name = r.Name })
                .ToListAsync();
        }

        public async Task<RoleApplicationResponse> SubmitAsync(RoleApplicationSubmitRequest request)
        {
            var userId = _authorization.RequireUserId();
            await _submitValidator.ValidateAndThrowAsync(request);

            var role = await _dbContext.Roles.FirstOrDefaultAsync(r => r.Id == request.RoleId)
                ?? throw new BusinessRuleException("The selected role does not exist.");

            // Only elevated roles are applied for; Admin/Traveler are never obtained this way.
            if (role.Name != RoleNames.Curator && role.Name != RoleNames.Organizer)
            {
                throw new BusinessRuleException("You can only apply for the Curator or Organizer role.");
            }

            if (await _dbContext.UserRoles.AnyAsync(ur => ur.UserId == userId && ur.RoleId == role.Id))
            {
                throw new BusinessRuleException($"You already hold the {role.Name} role.");
            }

            if (await _dbContext.RoleApplications.AnyAsync(a =>
                    a.UserId == userId && a.RoleId == role.Id && a.Status == RoleApplicationStatus.Pending))
            {
                throw new ConflictException($"You already have a pending {role.Name} application.");
            }

            if (request.RegionId.HasValue
                && !await _dbContext.Regions.AnyAsync(r => r.Id == request.RegionId.Value))
            {
                throw new BusinessRuleException("The selected region does not exist.");
            }

            // Optional supporting document: trust the bytes, not the declared type — verify the magic
            // bytes actually match the content type before storing (course §I).
            byte[]? document = null;
            string? documentContentType = null;
            if (request.Document is { Length: > 0 })
            {
                if (!FileSignatureValidator.IsValid(request.Document, request.DocumentContentType))
                {
                    throw new BusinessRuleException(
                        $"The attached document must be a valid file of type: {string.Join(", ", FileSignatureValidator.AllowedContentTypes)}.");
                }

                document = request.Document;
                documentContentType = request.DocumentContentType!.Trim();
            }

            var application = new RoleApplication
            {
                UserId = userId,
                RoleId = role.Id,
                Motivation = request.Motivation,
                RegionId = request.RegionId,
                Document = document,
                DocumentContentType = documentContentType,
                Status = RoleApplicationStatus.Pending
            };

            _dbContext.RoleApplications.Add(application);
            await _dbContext.SaveChangesAsync();

            return await RequireResponseAsync(application.Id);
        }

        public async Task<RoleApplicationResponse> ApproveAsync(int id)
        {
            // Deciding is admin-only. The controller policy is the first gate; this makes the service
            // its own boundary so the check holds no matter how the method is reached.
            _authorization.EnsureInRole(RoleNames.Admin);
            var adminId = _authorization.RequireUserId();

            var application = await _dbContext.RoleApplications.FirstOrDefaultAsync(a => a.Id == id)
                ?? throw new NotFoundException("RoleApplication", id);

            EnsurePending(application);

            application.Status = RoleApplicationStatus.Approved;
            application.DecidedByUserId = adminId;
            application.DecidedAt = DateTime.UtcNow;

            // Grant the role live. Idempotent: only add the link if the user doesn't already hold it
            // (they may have been granted it by another path since applying).
            if (!await _dbContext.UserRoles.AnyAsync(ur => ur.UserId == application.UserId && ur.RoleId == application.RoleId))
            {
                _dbContext.UserRoles.Add(new UserRole { UserId = application.UserId, RoleId = application.RoleId });
            }

            // Force the applicant to re-authenticate so their next token carries the new role: revoke
            // their refresh tokens. Their current (stateless) access token stays valid until it expires,
            // at which point the failed refresh logs them out and re-login issues a JWT with the role.
            _dbContext.RefreshTokens.RemoveRange(
                _dbContext.RefreshTokens.Where(rt => rt.UserId == application.UserId));

            var roleName = await _dbContext.Roles
                .Where(r => r.Id == application.RoleId)
                .Select(r => r.Name)
                .FirstAsync();

            AddDecisionNotification(
                application.UserId,
                NotificationType.RoleApplicationApproved,
                "Role application approved",
                $"Your application for the {roleName} role has been approved.",
                application.Id);

            // Decision + role grant + notification in one SaveChanges = one implicit transaction.
            await _dbContext.SaveChangesAsync();

            return await RequireResponseAsync(application.Id);
        }

        public async Task<RoleApplicationResponse> RejectAsync(int id, RoleApplicationRejectRequest request)
        {
            _authorization.EnsureInRole(RoleNames.Admin);
            var adminId = _authorization.RequireUserId();
            await _rejectValidator.ValidateAndThrowAsync(request);

            var application = await _dbContext.RoleApplications.FirstOrDefaultAsync(a => a.Id == id)
                ?? throw new NotFoundException("RoleApplication", id);

            EnsurePending(application);

            application.Status = RoleApplicationStatus.Rejected;
            application.DecidedByUserId = adminId;
            application.DecidedAt = DateTime.UtcNow;
            application.RejectionReason = request.Reason;

            var roleName = await _dbContext.Roles
                .Where(r => r.Id == application.RoleId)
                .Select(r => r.Name)
                .FirstAsync();

            AddDecisionNotification(
                application.UserId,
                NotificationType.RoleApplicationRejected,
                "Role application rejected",
                $"Your application for the {roleName} role was not approved. Reason: {request.Reason}",
                application.Id);

            await _dbContext.SaveChangesAsync();

            return await RequireResponseAsync(application.Id);
        }

        public async Task<(byte[] Content, string ContentType)?> GetDocumentAsync(int id)
        {
            var application = await _dbContext.RoleApplications
                .AsNoTracking()
                .Where(a => a.Id == id)
                .Select(a => new { a.UserId, a.Document, a.DocumentContentType })
                .FirstOrDefaultAsync()
                ?? throw new NotFoundException("RoleApplication", id);

            _authorization.EnsureSelfOrAdmin(application.UserId, "application");

            if (application.Document is null || application.Document.Length == 0)
            {
                return null;
            }

            return (application.Document, application.DocumentContentType ?? "application/octet-stream");
        }

        private static void EnsurePending(RoleApplication application)
        {
            if (application.Status != RoleApplicationStatus.Pending)
            {
                throw new BusinessRuleException("This application has already been decided.");
            }
        }

        // INTERIM: the Notifications service and SignalR real-time push do not exist yet (they arrive in
        // Phase 9). The in-app row is written directly here so the decision is recorded and visible now;
        // when the notification pipeline lands, this must be routed through it (real-time push + any
        // email). Tracked in the travle-notifications-deferred memory.
        private void AddDecisionNotification(int userId, NotificationType type, string title, string text, int relatedEntityId)
        {
            _dbContext.Notifications.Add(new Notification
            {
                UserId = userId,
                Type = type,
                Title = title,
                Text = text,
                RelatedEntityId = relatedEntityId,
                IsRead = false
            });
        }

        private async Task<RoleApplication> LoadWithNavigationsAsync(int id)
            => await _dbContext.RoleApplications
                   .AsNoTracking()
                   .Include(a => a.User)
                   .Include(a => a.Role)
                   .Include(a => a.Region)
                   .Include(a => a.DecidedByUser)
                   .FirstOrDefaultAsync(a => a.Id == id)
               ?? throw new NotFoundException("RoleApplication", id);

        // Re-reads a just-mutated application fully hydrated so the response DTO is complete. Internal
        // (no ownership check) — callers have already authorized the action.
        private async Task<RoleApplicationResponse> RequireResponseAsync(int id)
            => _mapper.Map<RoleApplicationResponse>(await LoadWithNavigationsAsync(id));
    }
}
