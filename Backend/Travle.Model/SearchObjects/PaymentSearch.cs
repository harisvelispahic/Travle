namespace Travle.Model.SearchObjects
{
    /// <summary>
    /// Filters for the admin payments list (and the matching totals). <see cref="Status"/> is the
    /// <c>PaymentStatus</c> int; the date range is on the payment's creation instant (UTC). <see cref="Text"/>
    /// matches the traveler (name/username) or the tour name.
    /// </summary>
    public class PaymentSearch : BaseSearchObject
    {
        /// <summary>Filter by payment status (the <c>PaymentStatus</c> enum value).</summary>
        public int? Status { get; set; }

        /// <summary>Only payments created on/after this instant (UTC).</summary>
        public DateTime? FromDate { get; set; }

        /// <summary>Only payments created before this instant (UTC).</summary>
        public DateTime? ToDate { get; set; }

        /// <summary>Free-text match on the traveler's name/username or the tour name.</summary>
        public string? Text { get; set; }
    }
}
