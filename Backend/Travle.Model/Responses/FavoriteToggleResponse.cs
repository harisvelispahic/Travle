namespace Travle.Model.Responses
{
    /// <summary>
    /// The result of toggling a favorite: the new state after the toggle. <see cref="IsFavorite"/> is true
    /// when the target is now favorited, false when it was just removed — the client flips the heart from
    /// this rather than assuming the outcome.
    /// </summary>
    public class FavoriteToggleResponse
    {
        /// <summary>"Destination" or "Tour" — echoes which target was toggled.</summary>
        public string TargetType { get; set; } = string.Empty;
        public int TargetId { get; set; }

        /// <summary>True if the target is now in the user's favorites, false if it was just removed.</summary>
        public bool IsFavorite { get; set; }
    }
}
