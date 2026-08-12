namespace Travle.Model.SearchObjects
{
    /// <summary>
    /// Filters for the map-browse endpoint. The bounding box is the mandatory search parameter — the four
    /// edges of the currently visible map (a plain WGS84 rectangle) — and only Approved destinations inside
    /// it are returned, capped server-side (see the service). <see cref="CategoryIds"/> and
    /// <see cref="MinRating"/> are optional and mirror the destination search filters so the map's filter
    /// chips reuse the same signals; the category filter is multi-select (any of the chosen categories).
    /// Paging fields from the base are ignored: the map returns a capped list, not a page.
    /// </summary>
    public class DestinationMapSearch : BaseSearchObject
    {
        /// <summary>Southern edge (minimum latitude) of the visible map, in degrees.</summary>
        public double? South { get; set; }

        /// <summary>Western edge (minimum longitude) of the visible map, in degrees.</summary>
        public double? West { get; set; }

        /// <summary>Northern edge (maximum latitude) of the visible map, in degrees.</summary>
        public double? North { get; set; }

        /// <summary>Eastern edge (maximum longitude) of the visible map, in degrees.</summary>
        public double? East { get; set; }

        /// <summary>Show only destinations in any of these categories (empty/null = all categories).</summary>
        public List<int>? CategoryIds { get; set; }

        /// <summary>Minimum average rating (inclusive).</summary>
        public double? MinRating { get; set; }
    }
}
