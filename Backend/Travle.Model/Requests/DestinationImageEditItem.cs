namespace Travle.Model.Requests
{
    /// <summary>
    /// One entry in a destination edit's desired image set. An item with an <see cref="Id"/> is an
    /// existing image to keep (only its <see cref="SortOrder"/> may change); an item with
    /// <see cref="Data"/> is a new image to add (validated + thumbnailed server-side). Existing images
    /// whose id is absent from the submitted list are deleted. This single ordered list expresses
    /// add / remove / reorder in one request.
    /// </summary>
    public class DestinationImageEditItem
    {
        /// <summary>Set for an existing image being kept; null for a newly added image.</summary>
        public int? Id { get; set; }

        /// <summary>Set for a newly added image; null when keeping an existing one.</summary>
        public byte[]? Data { get; set; }
        public string? ContentType { get; set; }

        public int SortOrder { get; set; }
    }
}
