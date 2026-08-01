using System.ComponentModel.DataAnnotations;

namespace Travle.WebAPI.Options
{
    /// <summary>
    /// Settings for the in-process pre-tour reminder sweep (run by <c>BookingLifecycleWorker</c>). Bound
    /// from the <c>BookingReminder</c> configuration section. The spec's reminder is 24 hours before the
    /// tour; the window is configurable so it can also be widened for a live demo, since seed schedule dates
    /// are static and won't naturally fall 24 hours ahead of run time (see docs/notifications-and-signalr.md §6).
    /// </summary>
    public sealed class BookingReminderOptions
    {
        public const string SectionName = "BookingReminder";

        /// <summary>How far ahead of a tour's start a reminder is sent, in hours. Default 24 (the spec).</summary>
        [Range(1, 100000)]
        public int WindowHours { get; set; } = 24;
    }
}
