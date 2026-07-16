namespace Travle.Services.Database
{
    /// <summary>
    /// Composition child of a <see cref="Destination"/>: full image bytes plus a small thumbnail for
    /// list DTOs. Cascades away with its destination; individually deletable while editing.
    /// </summary>
    public class DestinationImage : BaseEntity
    {
        public int DestinationId { get; set; }
        public Destination Destination { get; set; } = null!;

        public byte[] ImageData { get; set; } = Array.Empty<byte>();
        public byte[] ThumbnailData { get; set; } = Array.Empty<byte>();
        public string ContentType { get; set; } = string.Empty;

        public int SortOrder { get; set; }
    }
}
