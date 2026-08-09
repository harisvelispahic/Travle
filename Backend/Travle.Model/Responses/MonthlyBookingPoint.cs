namespace Travle.Model.Responses
{
    /// <summary>
    /// One bar of the "bookings per month" chart: the count of bookings created in a given calendar
    /// month (UTC). The series always carries a continuous run of months (gaps filled with zero) so the
    /// chart has no missing columns. <see cref="Label"/> is a ready-to-render "Mon yyyy" caption.
    /// </summary>
    public class MonthlyBookingPoint
    {
        public int Year { get; set; }
        public int Month { get; set; }
        public int Count { get; set; }

        /// <summary>Short display caption, e.g. "Aug 2026".</summary>
        public string Label { get; set; } = string.Empty;
    }
}
