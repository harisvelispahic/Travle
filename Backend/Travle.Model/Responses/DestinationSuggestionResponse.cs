namespace Travle.Model.Responses
{
    /// <summary>
    /// The minimal shape returned by the search-autocomplete endpoint (<c>GET /Destinations/suggest</c>):
    /// just enough to render a typeahead row and let the user pick a name — id, name, and the city/category
    /// shown as secondary context. Deliberately text-only (no thumbnail bytes, tags, or description): the
    /// endpoint fires on every debounced keystroke, so the payload stays as small as possible, and it records
    /// no recommender interaction (the real <c>Search</c> signal is written when the full search is submitted).
    /// </summary>
    public class DestinationSuggestionResponse
    {
        public int Id { get; set; }

        public string Name { get; set; } = string.Empty;

        public string? CityName { get; set; }

        public string? CategoryName { get; set; }
    }
}
