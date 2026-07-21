using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;

namespace Travle.Services
{
    /// <summary>
    /// Curator/Organizer role applications: users submit, admins decide. Reads inherit the paginated
    /// list (admin moderation queue) and detail from <see cref="IBaseReadService{TResponse,TSearch}"/>;
    /// the detail read is scoped to the owner or an admin.
    /// </summary>
    public interface IRoleApplicationService : IBaseReadService<RoleApplicationResponse, RoleApplicationSearch>
    {
        /// <summary>Current user applies for the Curator or Organizer role (user taken from the JWT).</summary>
        Task<RoleApplicationResponse> SubmitAsync(RoleApplicationSubmitRequest request);

        /// <summary>
        /// Admin approves a pending application: grants the role live (adds the UserRole if missing),
        /// records the audit trail, and writes the applicant a notification. The granted role appears
        /// in the applicant's JWT on their next token issuance (refresh or re-login).
        /// </summary>
        Task<RoleApplicationResponse> ApproveAsync(int id);

        /// <summary>Admin rejects a pending application with a mandatory reason; records audit + notifies.</summary>
        Task<RoleApplicationResponse> RejectAsync(int id, RoleApplicationRejectRequest request);

        /// <summary>The current user's own applications (any status), paginated.</summary>
        Task<PageResult<RoleApplicationResponse>> GetMineAsync(RoleApplicationSearch? search);

        /// <summary>
        /// The supporting document bytes + content type for download, or <c>null</c> when the
        /// application has no attachment. Owner-or-admin only.
        /// </summary>
        Task<(byte[] Content, string ContentType)?> GetDocumentAsync(int id);
    }
}
