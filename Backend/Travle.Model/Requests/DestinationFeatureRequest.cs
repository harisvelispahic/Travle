namespace Travle.Model.Requests
{
    /// <summary>
    /// An admin's toggle of a destination's featured flag (drives the mobile "Featured" home section).
    /// Only an approved destination may be featured — enforced in the service.
    /// </summary>
    public class DestinationFeatureRequest
    {
        public bool IsFeatured { get; set; }
    }
}
