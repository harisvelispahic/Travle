using System.Linq.Expressions;
using Travle.Services.Database;

namespace Travle.Services.Visibility
{
    /// <summary>
    /// The single definition of what a traveler may see and book.
    ///
    /// The rule was previously restated at each entry point, and the restatements drifted: public search
    /// and the tour detail hid a tour whose stop had left the approved catalogue, but the schedules
    /// endpoint and the booking guard did not — so a tour could vanish from browse while a remembered
    /// <c>scheduleId</c> stayed enough to book it. Favorites, the organizer's public profile and the
    /// recommender each had their own partial version of the same idea.
    ///
    /// Everything that returns or consumes traveler content now composes these, so there is one condition
    /// to read, one to change, and one to defend. Organizer- and admin-facing reads deliberately do not
    /// apply them: an organizer must still see their own deactivated or temporarily unavailable tour in
    /// order to act on it.
    /// </summary>
    public static class TravelerVisibility
    {
        /// <summary>
        /// A tour a traveler may browse and book: published by its organizer, run by an account that can
        /// still confirm bookings, and visiting only destinations that are currently approved. All three
        /// reverse on their own — reactivating the tour, lifting the suspension, or re-approving the stop
        /// brings it back, because nothing here is destructive.
        /// </summary>
        public static readonly Expression<Func<Tour, bool>> TourIsBookable =
            t => t.IsActive
                 && !t.Organizer.IsSuspended
                 && t.TourDestinations.All(td => td.Destination.Status == DestinationStatus.Approved);

        /// <summary>
        /// The itinerary half of <see cref="TourIsBookable"/> on its own, for the one caller that composes
        /// the three conditions separately: the tours list applies activation and organizer suspension as
        /// independent search filters (an organizer's own view keeps them off so they still see a flagged
        /// tour), and switches this part on only for public browse. Same expression either way, so browse
        /// and the booking guard cannot drift.
        /// </summary>
        public static readonly Expression<Func<Tour, bool>> AllStopsApproved =
            t => t.TourDestinations.All(td => td.Destination.Status == DestinationStatus.Approved);

        /// <summary>A destination a traveler may see: approved, and therefore published.</summary>
        public static readonly Expression<Func<Destination, bool>> DestinationIsVisible =
            d => d.Status == DestinationStatus.Approved;

        /// <summary>Narrows a tour query to what travelers may browse and book.</summary>
        public static IQueryable<Tour> BookableToTravelers(this IQueryable<Tour> query)
            => query.Where(TourIsBookable);

        /// <summary>Narrows a destination query to what travelers may see.</summary>
        public static IQueryable<Destination> VisibleToTravelers(this IQueryable<Destination> query)
            => query.Where(DestinationIsVisible);
    }
}
