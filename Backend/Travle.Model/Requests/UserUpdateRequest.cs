namespace Travle.Model.Requests
{
    /// <summary>
    /// Profile edit (self or admin). Nullable fields so a partial update never forces re-entering
    /// every value (course §I); nulls are ignored by the mapper. Never carries a role, password, or
    /// suspension state — those have their own endpoints.
    /// </summary>
    public class UserUpdateRequest
    {
        public string? FirstName { get; set; }
        public string? LastName { get; set; }
        public string? Email { get; set; }
        public string? Username { get; set; }
        public string? PhoneNumber { get; set; }
        public int? CityId { get; set; }
        public byte[]? ProfileImage { get; set; }

        /// <summary>MIME type of <see cref="ProfileImage"/>. Required when an image is supplied; must be
        /// image/jpeg or image/png, and the bytes are verified against it (magic-byte check).</summary>
        public string? ProfileImageContentType { get; set; }
    }
}
