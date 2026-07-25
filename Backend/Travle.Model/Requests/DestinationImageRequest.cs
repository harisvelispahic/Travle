namespace Travle.Model.Requests
{
    /// <summary>
    /// A new image attached to a destination on submit. <see cref="Data"/> is the raw bytes (a base64
    /// string over the wire); the server verifies them against <see cref="ContentType"/> by magic bytes
    /// and generates the thumbnail — the client never supplies a thumbnail (rule 3).
    /// </summary>
    public class DestinationImageRequest
    {
        public byte[]? Data { get; set; }
        public string? ContentType { get; set; }
        public int SortOrder { get; set; }
    }
}
