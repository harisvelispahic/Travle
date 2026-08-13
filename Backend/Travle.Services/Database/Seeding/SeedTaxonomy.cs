namespace Travle.Services.Database.Seeding
{
    /// <summary>
    /// Canonical reference lists for the classification tables (categories, tags, tour types). The first
    /// entries mirror the HasData core exactly so the name-based upsert re-uses those rows (and the existing
    /// destinations/tours keep their category/tag/type ids); everything after enriches the catalogue.
    /// </summary>
    internal static class SeedTaxonomy
    {
        public static readonly string[] Categories =
        {
            // Core (HasData ids 1-7) — keep names verbatim.
            "Historical Site", "Natural Wonder", "Religious Site", "Cultural Landmark", "Adventure",
            "Museum", "Old Town",
            // Enrichment.
            "Fortress & Castle", "Waterfall", "Lake", "River & Spring", "Mountain & Peak", "National Park",
            "Bridge", "Archaeological Site", "Monument & Memorial", "Cave", "Canyon", "Viewpoint",
            "Park & Garden",
        };

        public static readonly string[] Tags =
        {
            // Core (HasData ids 1-17) — keep names verbatim.
            "UNESCO", "Waterfall", "Ottoman", "Medieval", "Hiking", "Photography", "Family Friendly",
            "River", "Bridge", "Fortress", "Nature", "Swimming", "Pilgrimage", "Old Town", "Mountains",
            "Museum", "Architecture",
            // Enrichment.
            "Austro-Hungarian", "Illyrian", "Roman", "Stećci", "Canyon", "Cave", "Lake", "Spring",
            "Cycling", "Rafting", "Skiing", "Wildlife", "Romantic", "Mosque", "Church", "Monastery",
            "Synagogue", "Bazaar", "Panoramic View", "Picnic", "Wine", "Food", "Traditional Crafts",
            "Memorial", "War History", "National Park", "Off the Beaten Path", "Sunset", "Spa & Wellness",
            "Winter",
        };

        public static readonly string[] TourTypes =
        {
            // Core (HasData ids 1-5) — keep names verbatim.
            "Walking Tour", "Cultural Tour", "Adventure Tour", "Food Tour", "Private Tour",
            // Enrichment.
            "Historical Tour", "Nature & Hiking Tour", "Photography Tour", "Rafting & Water Tour",
            "Religious & Pilgrimage Tour", "City Sightseeing", "Multi-Day Tour", "Cycling Tour",
            "Wine & Gastronomy Tour",
        };
    }
}
