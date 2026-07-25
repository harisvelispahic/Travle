namespace Travle.Model.Responses
{
    /// <summary>
    /// Lightweight tag reference (id + name) embedded in richer responses such as
    /// <see cref="DestinationResponse.Tags"/>. The id lets an edit form preselect the tag chips; the
    /// name is shown on screen (never a raw id). The full <see cref="TagResponse"/> with timestamps is
    /// used only by the tag reference-CRUD endpoints.
    /// </summary>
    public class TagRef
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
    }
}
