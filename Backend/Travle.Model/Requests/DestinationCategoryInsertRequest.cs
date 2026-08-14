namespace Travle.Model.Requests
{
    /// <summary>
    /// Admin create for a destination category. <see cref="Image"/> is the raw bytes (a base64 string over
    /// the wire, like <see cref="DestinationImageRequest.Data"/>); the server verifies them against
    /// <see cref="ImageContentType"/> by magic bytes and generates the thumbnail — the client never supplies
    /// a thumbnail (rule 3).
    /// </summary>
    public class DestinationCategoryInsertRequest
    {
        public string Name { get; set; } = string.Empty;
        public string? Description { get; set; }

        public byte[]? Image { get; set; }
        public string? ImageContentType { get; set; }
    }
}
