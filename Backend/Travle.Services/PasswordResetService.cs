using Travle.Model.Access;
using Travle.Model.Exceptions;
using Travle.Model.Messaging;
using Travle.Services.Database;
using Travle.Services.Messaging;
using Travle.Services.Notifications;
using Travle.Services.Security;
using FluentValidation;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using System.Security.Cryptography;

namespace Travle.Services
{
    public class PasswordResetService : IPasswordResetService
    {
        // A short window keeps a leaked/guessed code useless quickly; the code is single-use anyway.
        private const int CodeLifetimeMinutes = 15;

        // Same generic message for every failure path (unknown email, no code, wrong/expired code),
        // so the reset endpoint reveals nothing and can't be brute-forced by error signal.
        private const string GenericFailure = "The reset code is invalid or has expired.";

        private readonly TravleDbContext _dbContext;
        private readonly ICryptoService _cryptoService;
        private readonly IEmailPublisher _emailPublisher;
        private readonly IUserSecurityStore _securityStore;
        private readonly INotificationDispatcher _notifications;
        private readonly IValidator<ForgotPasswordRequest> _forgotValidator;
        private readonly IValidator<ResetPasswordRequest> _resetValidator;
        private readonly ILogger<PasswordResetService> _logger;

        public PasswordResetService(
            TravleDbContext dbContext,
            ICryptoService cryptoService,
            IEmailPublisher emailPublisher,
            IUserSecurityStore securityStore,
            INotificationDispatcher notifications,
            IValidator<ForgotPasswordRequest> forgotValidator,
            IValidator<ResetPasswordRequest> resetValidator,
            ILogger<PasswordResetService> logger)
        {
            _dbContext = dbContext;
            _cryptoService = cryptoService;
            _emailPublisher = emailPublisher;
            _securityStore = securityStore;
            _notifications = notifications;
            _forgotValidator = forgotValidator;
            _resetValidator = resetValidator;
            _logger = logger;
        }

        public async Task RequestResetAsync(ForgotPasswordRequest request, CancellationToken cancellationToken = default)
        {
            await _forgotValidator.ValidateAndThrowAsync(request, cancellationToken);

            var user = await _dbContext.Users.FirstOrDefaultAsync(u => u.Email == request.Email, cancellationToken);

            // Silently no-op for unknown or suspended accounts — the caller gets the same response
            // either way (anti-enumeration).
            if (user is null || user.IsSuspended)
            {
                _logger.LogInformation("Password reset requested for a non-actionable address; no code issued.");
                return;
            }

            // One live code at a time: drop any previous unused codes for this user.
            _dbContext.PasswordResetCodes.RemoveRange(
                _dbContext.PasswordResetCodes.Where(c => c.UserId == user.Id && c.UsedAt == null));

            var code = RandomNumberGenerator.GetInt32(0, 1_000_000).ToString("D6");
            var salt = _cryptoService.GenerateSalt();

            var resetCode = new PasswordResetCode
            {
                UserId = user.Id,
                // Salt embedded PHC-style ("salt:hash") — base64 never contains ':', so the split is safe.
                CodeHash = $"{salt}:{_cryptoService.GenerateHash(code, salt)}",
                ExpiresAt = DateTime.UtcNow.AddMinutes(CodeLifetimeMinutes)
            };

            _dbContext.PasswordResetCodes.Add(resetCode);
            await _dbContext.SaveChangesAsync(cancellationToken);

            // Only the plaintext code (never stored) leaves — carried by the message to the worker.
            await _emailPublisher.PublishPasswordResetAsync(new PasswordResetEmailMessage
            {
                ToEmail = user.Email,
                ToName = user.FirstName,
                Code = code,
                ExpiresAtUtc = resetCode.ExpiresAt
            }, cancellationToken);
        }

        public async Task ResetPasswordAsync(ResetPasswordRequest request)
        {
            await _resetValidator.ValidateAndThrowAsync(request);

            var user = await _dbContext.Users.FirstOrDefaultAsync(u => u.Email == request.Email);
            if (user is null)
            {
                throw new BusinessRuleException(GenericFailure);
            }

            var now = DateTime.UtcNow;
            var resetCode = await _dbContext.PasswordResetCodes
                .Where(c => c.UserId == user.Id && c.UsedAt == null && c.ExpiresAt > now)
                .OrderByDescending(c => c.CreatedAt)
                .FirstOrDefaultAsync();

            if (resetCode is null || !CodeMatches(resetCode.CodeHash, request.Code))
            {
                throw new BusinessRuleException(GenericFailure);
            }

            // A reset must actually change the password (course §4). The user proved control of the
            // account by supplying a valid code, so rejecting a same-as-current password here leaks
            // nothing they don't already control.
            if (_cryptoService.Verify(user.PasswordHash, user.PasswordSalt, request.NewPassword))
            {
                throw new BusinessRuleException("Your new password must be different from your old password.");
            }

            user.PasswordSalt = _cryptoService.GenerateSalt();
            user.PasswordHash = _cryptoService.GenerateHash(request.NewPassword, user.PasswordSalt);
            resetCode.UsedAt = now;

            // A password reset ends every existing session: bump the security stamp (rejects existing
            // access tokens on their next request) and drop all refresh tokens.
            user.SecurityStamp = SecurityStamps.New();
            _dbContext.RefreshTokens.RemoveRange(_dbContext.RefreshTokens.Where(rt => rt.UserId == user.Id));

            // Session-affecting push: any device still logged in on the old password is force-logged-out
            // immediately (its silent refresh fails — refresh tokens are gone — and it routes to login),
            // the same mechanism as a suspension. Flushed by the global filter once this action commits.
            _notifications.Enqueue(user.Id, NotificationType.PasswordChanged,
                "Password changed",
                "Your password was reset. For your security, you've been signed out on all devices.",
                relatedEntityId: null, alsoEmail: true);

            await _dbContext.SaveChangesAsync();
            _securityStore.Invalidate(user.Id);
        }

        private bool CodeMatches(string storedHash, string submittedCode)
        {
            var parts = storedHash.Split(':', 2);
            return parts.Length == 2 && _cryptoService.Verify(parts[1], parts[0], submittedCode);
        }
    }
}
