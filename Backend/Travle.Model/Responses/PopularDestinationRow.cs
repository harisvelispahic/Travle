namespace Travle.Model.Responses
{
    /// <summary>
    /// One ranked row of the "most popular destinations by period" report. Popularity is the number of
    /// bookings placed in the period on tours that include the destination (a booking on a multi-stop
    /// tour counts for every stop). <see cref="Views"/> and <see cref="Favorites"/> are all-time
    /// engagement columns shown for context. Rank is the 1-based position in the returned order.
    /// </summary>
    public class PopularDestinationRow
    {
        public int Rank { get; set; }
        public string DestinationName { get; set; } = string.Empty;
        public string CategoryName { get; set; } = string.Empty;
        public string RegionName { get; set; } = string.Empty;

        /// <summary>Bookings in the period on tours visiting this destination.</summary>
        public int Bookings { get; set; }

        /// <summary>Total travelers across those bookings.</summary>
        public int Travelers { get; set; }

        /// <summary>All-time view count (denormalized on the destination).</summary>
        public int Views { get; set; }

        /// <summary>All-time favorite count.</summary>
        public int Favorites { get; set; }
    }
}
