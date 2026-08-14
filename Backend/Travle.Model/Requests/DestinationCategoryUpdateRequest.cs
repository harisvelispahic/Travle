namespace Travle.Model.Requests
{
    /// <summary>
    /// Admin update for a destination category. A non-null <see cref="Image"/> replaces the illustration
    /// (re-verified by magic bytes and re-thumbnailed server-side); a null <see cref="Image"/> keeps the
    /// existing one untouched, so an edit that only changes the name/description need not resend the bytes.
    /// </summary>
    public class DestinationCategoryUpdateRequest
    {
        public string Name { get; set; } = string.Empty;
        public string? Description { get; set; }

        public byte[]? Image { get; set; }
        public string? ImageContentType { get; set; }
    }
}
