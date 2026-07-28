using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;

namespace Travle.Services
{
    /// <summary>
    /// Favorites: a per-user toggle over exactly one target (a destination or a tour) plus the two "my
    /// favorites" lists. Toggling a destination on records a <c>Favorite</c> interaction (recommender
    /// fuel); toggling off hard-deletes the row but leaves that interaction in place (the diary is
    /// append-only, 03 §3). Tour favorites are functional but record no interaction (the recommender
    /// feature space is destination-based). The favorite lists reuse the shared destination/tour card
    /// projections and are paginated, searchable, and newest-favorited first.
    /// </summary>
    public interface IFavoriteService
    {
        /// <summary>Toggles the favorite for the current user; returns the resulting state.</summary>
        Task<FavoriteToggleResponse> ToggleAsync(FavoriteToggleRequest request);

        /// <summary>The current user's favorited destinations (card DTOs), newest favorited first, paginated.</summary>
        Task<PageResult<DestinationResponse>> GetMyDestinationsAsync(DestinationSearch? search);

        /// <summary>The current user's favorited tours (card DTOs), newest favorited first, paginated.</summary>
        Task<PageResult<TourResponse>> GetMyToursAsync(TourSearch? search);
    }
}
