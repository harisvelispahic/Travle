namespace Travle.Model.Requests
{
    /// <summary>
    /// Edit of an existing destination by its submitter (or an admin). Any edit sends the destination
    /// back to <c>Pending</c> for re-moderation (enforced in the service). <see cref="Images"/> is the
    /// full desired image set (keep / add / remove / reorder expressed at once — see
    /// <see cref="DestinationImageEditItem"/>); <see cref="TagIds"/> is the full desired tag set.
    /// </summary>
    public class DestinationUpdateRequest
    {
        public string Name { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;

        public int CategoryId { get; set; }
        public int CityId { get; set; }

        public double Latitude { get; set; }
        public double Longitude { get; set; }

        public List<int> TagIds { get; set; } = new List<int>();
        public List<DestinationImageEditItem> Images { get; set; } = new List<DestinationImageEditItem>();
    }
}
