namespace Travle.Services.Database.Seeding
{
    /// <summary>
    /// Onboarding-card content for the seeded categories: a short description plus the file slug of the
    /// embedded illustration (<c>Database/Seeding/CategoryImages/&lt;Slug&gt;.png</c>, marked as an
    /// <c>EmbeddedResource</c>). Applied idempotently on startup by <c>SeedCategoryContentAsync</c> — the
    /// description backfills any category still missing one, and the image is loaded (and thumbnailed) only
    /// when the matching PNG asset is present, so this is safe to ship before every asset is embedded.
    /// Names must match <see cref="SeedTaxonomy.Categories"/> verbatim (that is how a row is found).
    /// </summary>
    internal static class SeedCategoryContent
    {
        public sealed record Entry(string Name, string Slug, string Description);

        public static readonly Entry[] Entries =
        {
            new("Historical Site", "historical-site",
                "Places where the past still stands — ruins, quarters and landmarks that shaped the region."),
            new("Natural Wonder", "natural-wonder",
                "Nature at its most striking: dramatic landscapes carved by water, wind and time."),
            new("Religious Site", "religious-site",
                "Mosques, churches, monasteries and shrines — centuries of faith and quiet beauty."),
            new("Cultural Landmark", "cultural-landmark",
                "Icons of local identity: squares, theatres and monuments at the heart of city life."),
            new("Adventure", "adventure",
                "For the restless: rafting, climbing, ziplines and trails that get the pulse going."),
            new("Museum", "museum",
                "Collections that tell the story — art, history and heritage under one roof."),
            new("Old Town", "old-town",
                "Cobbled lanes, artisan stalls and old-world charm in the historic core."),
            new("Fortress & Castle", "fortress-castle",
                "Ramparts and citadels standing guard over rivers, towns and mountain passes."),
            new("Waterfall", "waterfall",
                "Cascades and falls where rivers tumble through forest and stone."),
            new("Lake", "lake",
                "Still, mirror-clear waters ringed by mountains — made for a calm day out."),
            new("River & Spring", "river-spring",
                "Emerald rivers and karst springs, cold and impossibly clear."),
            new("Mountain & Peak", "mountain-peak",
                "High country and summit views for hikers, skiers and the simply curious."),
            new("National Park", "national-park",
                "Protected wilds where forests, canyons and wildlife are left to thrive."),
            new("Bridge", "bridge",
                "Storied crossings — from stone Ottoman arches to icons that define a skyline."),
            new("Archaeological Site", "archaeological-site",
                "Layers of civilisation unearthed: settlements, necropolises and ancient stones."),
            new("Monument & Memorial", "monument-memorial",
                "Places of remembrance that honour the people and events that made history."),
            new("Cave", "cave",
                "Underground worlds of stalactites, chambers and hidden rivers."),
            new("Canyon", "canyon",
                "Sheer gorges and dizzying drops sculpted by rushing water."),
            new("Viewpoint", "viewpoint",
                "Panoramic lookouts where the whole landscape opens up before you."),
            new("Park & Garden", "park-garden",
                "Green retreats to stroll, picnic and unwind, away from the bustle."),
        };
    }
}
