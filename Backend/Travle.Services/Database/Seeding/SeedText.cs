namespace Travle.Services.Database.Seeding
{
    /// <summary>A demo account created by the bulk seeder. All share the password "test".</summary>
    internal sealed record UserSeed(string FirstName, string LastName, string Username, string Email, string Role, bool Outlier = false);

    /// <summary>One of the fixed, graded demo logins (stable usernames, possibly multi-role). Password "test".</summary>
    internal sealed record CoreUserSeed(string FirstName, string LastName, string Username, string Email, string[] Roles, bool IsOnboarded = false);

    /// <summary>Copy pools and generated accounts for the bulk seed. Kept out of <see cref="BulkSeeder"/> so
    /// the orchestration reads cleanly. Comment pools are grouped by rating band so seeded reviews match their
    /// score.</summary>
    internal static class SeedText
    {
        public const string Admin = "Admin";
        public const string Curator = "Curator";
        public const string Organizer = "Organizer";
        public const string Traveler = "Traveler";

        // The four graded demo logins + the two extra organizers and the pending-applicant traveler, all
        // password "test". Usernames/roles mirror the original HasData accounts (README + docs depend on
        // them); "curator" is deliberately multi-role (Curator + Traveler). Ids are DB-assigned — nothing
        // depends on the specific user id, only the username.
        public static readonly CoreUserSeed[] CoreUsers =
        {
            new("Amela", "Admin", "desktop", "admin@travle.com", [Admin]),
            new("Omar", "Organizer", "organizer", "organizer@travle.com", [Organizer]),
            new("Kenan", "Curator", "curator", "curator@travle.com", [Curator, Traveler]),
            new("Mirza", "Traveler", "mobile", "mobile@travle.com", [Traveler], IsOnboarded: true),
            new("Lejla", "Traveler", "traveler2", "traveler2@travle.com", [Traveler]),
            new("Amir", "Hodžić", "amir_tours", "amir@travle.com", [Organizer]),
            new("Selma", "Begić", "selma_travel", "selma@travle.com", [Organizer]),
        };

        // ~35 accounts. Two curators and two organizers are flagged as outliers — the seeder gives them a
        // disproportionate share of destinations/tours so the statistics and charts have clear leaders.
        public static readonly UserSeed[] Users =
        {
            // Curators (submit destinations). Adnan & Marija are the outliers.
            new("Adnan", "Hodžić", "adnan_curator", "adnan.hodzic@travle.example", Curator, Outlier: true),
            new("Marija", "Perić", "marija_curator", "marija.peric@travle.example", Curator, Outlier: true),
            new("Emir", "Softić", "emir_curator", "emir.softic@travle.example", Curator),
            new("Ivana", "Kovač", "ivana_curator", "ivana.kovac@travle.example", Curator),
            new("Damir", "Babić", "damir_curator", "damir.babic@travle.example", Curator),
            new("Sanela", "Delić", "sanela_curator", "sanela.delic@travle.example", Curator),
            new("Nikola", "Jovanović", "nikola_curator", "nikola.jovanovic@travle.example", Curator),
            new("Amila", "Zukić", "amila_curator", "amila.zukic@travle.example", Curator),

            // Organizers (run tours). Bosna Adventures (Vedran) & Dinarik (Ana) are the outliers.
            new("Vedran", "Marić", "bosna_adventures", "vedran.maric@travle.example", Organizer, Outlier: true),
            new("Ana", "Vuković", "dinarik_tours", "ana.vukovic@travle.example", Organizer, Outlier: true),
            new("Haris", "Mujić", "haris_tours", "haris.mujic@travle.example", Organizer),
            new("Tanja", "Ilić", "tanja_travel", "tanja.ilic@travle.example", Organizer),
            new("Mirza", "Alić", "mirza_expeditions", "mirza.alic@travle.example", Organizer),
            new("Petra", "Novak", "petra_tours", "petra.novak@travle.example", Organizer),
            new("Senad", "Karić", "senad_guides", "senad.karic@travle.example", Organizer),

            // Travelers (browse, book, review).
            new("Lucija", "Horvat", "lucija_h", "lucija.horvat@travle.example", Traveler),
            new("Mehmedalija", "Begović", "mehmedalija_b", "mehmedalija.begovic@travle.example", Traveler),
            new("Jelena", "Popović", "jelena_p", "jelena.popovic@travle.example", Traveler),
            new("Tarik", "Hadžić", "tarik_h", "tarik.hadzic@travle.example", Traveler),
            new("Marko", "Kovačević", "marko_k", "marko.kovacevic@travle.example", Traveler),
            new("Amina", "Suljić", "amina_s", "amina.suljic@travle.example", Traveler),
            new("Stefan", "Đorđević", "stefan_dj", "stefan.djordjevic@travle.example", Traveler),
            new("Dženana", "Omerović", "dzenana_o", "dzenana.omerovic@travle.example", Traveler),
            new("Filip", "Matić", "filip_m", "filip.matic@travle.example", Traveler),
            new("Lamija", "Čaušević", "lamija_c", "lamija.causevic@travle.example", Traveler),
            new("Ahmed", "Hadžić", "ahmed_h", "ahmed.hadzic@travle.example", Traveler),
            new("Ajla", "Mehić", "ajla_m", "ajla.mehic@travle.example", Traveler),
            new("Kerim", "Alić", "kerim_a", "kerim.alic@travle.example", Traveler),
            new("Sara", "Tadić", "sara_t", "sara.tadic@travle.example", Traveler),
            new("Faris", "Isaković", "faris_i", "faris.isakovic@travle.example", Traveler),
            new("Kristina", "Šarić", "kristina_s", "kristina.saric@travle.example", Traveler),
            new("Ajdin", "Ramić", "ajdin_r", "ajdin.ramic@travle.example", Traveler),
            new("Milica", "Stanković", "milica_s", "milica.stankovic@travle.example", Traveler),
            new("Benjamin", "Halilović", "benjamin_h", "benjamin.halilovic@travle.example", Traveler),
            new("Ivona", "Barišić", "ivona_b", "ivona.barisic@travle.example", Traveler),
        };

        // Bosnian towns used as travelers' home cities (recommender/profile signal). Must exist in the seed.
        public static readonly string[] TravelerHomeCities =
        {
            "Sarajevo", "Mostar", "Tuzla", "Zenica", "Banja Luka", "Bihać", "Travnik", "Trebinje",
            "Doboj", "Bijeljina", "Prijedor", "Goražde",
        };

        // ---- Destination review comments, by rating band ----
        public static readonly string[] DestinationPraise =
        {
            "Absolutely breathtaking — worth every minute of the trip.",
            "One of the most beautiful places I have ever visited.",
            "Stunning scenery and so peaceful. Highly recommend.",
            "A hidden gem. We had it almost to ourselves.",
            "Incredible history and atmosphere. A must-see.",
            "Perfect for photos, the light in the afternoon is magical.",
            "Loved every second here. Will definitely come back.",
            "Even more impressive in person than in the pictures.",
            "Rich history and a wonderful local vibe.",
            "The views from the top are unforgettable.",
            "A real jewel of Bosnia and Herzegovina.",
            "Wonderful family day out — the kids loved it.",
            "Great value and genuinely memorable.",
            "Beautifully preserved and easy to reach.",
            "A magical, calming spot right by the water.",
        };

        public static readonly string[] DestinationNeutral =
        {
            "Nice place, though quite crowded when we went.",
            "Worth a short visit if you are in the area.",
            "Pretty, but there isn't a lot to do beyond the main sight.",
            "Good, but parking was a bit of a hassle.",
            "Interesting spot, a little run-down in places.",
            "Decent half-day trip. Bring water in summer.",
            "Fine, but the signage could be much better.",
            "Pleasant enough, nothing extraordinary.",
        };

        public static readonly string[] DestinationCritical =
        {
            "Disappointing — it was hard to find and poorly maintained.",
            "Too crowded and overpriced for what it is.",
            "Not much to see, would skip it next time.",
            "The facilities were closed when we arrived.",
        };

        /// <summary>
        /// The Srebrenica–Potočari Memorial is a genocide memorial and cemetery, not a tourist
        /// attraction — the generic praise/neutral/critical pools ("perfect for photos", "family day
        /// out", "would skip it") are inappropriate there. It gets its own pool of respectful,
        /// reflective reviews, all highly rated and never moderated off-topic. Matched by name
        /// (contains <see cref="SrebrenicaMemorialMatch"/>) in BulkSeeder.SeedReviewsAsync.
        /// </summary>
        public const string SrebrenicaMemorialMatch = "Potočari";

        public static readonly string[] SrebrenicaMemorialReflections =
        {
            "A deeply moving place. We came to pay our respects and left in silence. We must never forget.",
            "Every visitor to Bosnia should come here to understand what happened in July 1995. Harrowing and essential.",
            "The endless rows of white headstones are overwhelming. A place for reflection and remembrance.",
            "Heartbreaking and important — the memorial keeps alive the memory of the more than 8,000 victims of the genocide.",
            "We spent the morning here in quiet reflection. The exhibition treats the history with real dignity.",
            "A solemn, powerful reminder. Please come with respect and give yourself plenty of time.",
            "The Potočari cemetery is hard to put into words: grief, and the resolve that this must never happen again.",
            "An essential site of memory. The old battery-factory exhibition across the road is just as important to see.",
            "I will carry this visit with me for a long time. A dignified tribute to those who were killed.",
            "Come to listen and to learn, and to honour the Mothers of Srebrenica who fought for this memorial.",
            "Sombre and deeply affecting — a vital place of remembrance so that history is not repeated.",
            "We paid our respects to the victims. The silence here says more than any words could.",
        };

        // ---- Tour review comments, by rating band ----
        public static readonly string[] TourPraise =
        {
            "Fantastic guide — knowledgeable, funny and patient.",
            "Perfectly organised from start to finish. Thank you!",
            "The itinerary was spot on and the pace was great.",
            "Our guide made the history come alive. Loved it.",
            "Small group, personal attention, unforgettable day.",
            "Great value and we saw far more than we expected.",
            "Highly recommend — a real highlight of our trip.",
            "Everything ran smoothly and the guide was excellent.",
            "Wonderful stories and hidden spots we'd never have found.",
            "Booked easily and the whole day exceeded expectations.",
        };

        public static readonly string[] TourNeutral =
        {
            "Good tour overall, though it felt a little rushed.",
            "Enjoyable, but the pickup was a bit late.",
            "Nice experience; wish we'd had more free time at each stop.",
            "Solid tour, guide was friendly but a little quiet.",
            "Worthwhile, though the group was larger than expected.",
        };

        public static readonly string[] TourCritical =
        {
            "The schedule changed at the last minute, which was frustrating.",
            "Felt overpriced for what was included.",
            "The guide seemed rushed and we skipped a stop.",
        };

        public static readonly string[] SearchTerms =
        {
            "waterfall", "old town", "fortress", "mostar", "hiking", "unesco", "river", "mosque",
            "monastery", "lake", "rafting", "sarajevo", "medieval", "nature", "bridge",
        };

        public static readonly string[] CancellationReasons =
        {
            "Change of travel plans.", "Weather forecast looked bad.", "Family emergency.",
            "Found a different date that suited us better.", "Had to reschedule the trip.",
        };

        public static readonly string[] RejectionReasons =
        {
            "Group minimum not reached for this date.", "The guide is unavailable on this slot.",
            "Overbooked — apologies, please pick another date.",
        };

        public static readonly string[] CuratorMotivations =
        {
            "I am a local guide and want to help keep our region's sights accurate and up to date.",
            "I grew up here and know these landmarks well — I'd love to contribute them properly.",
            "As a history enthusiast I want to document the fortresses and old towns of my area.",
            "I run a small heritage blog and would like to curate destinations for travellers.",
        };

        public static readonly string[] OrganizerMotivations =
        {
            "I have guided tours in this region for years and want to offer them on the platform.",
            "Our small agency specialises in adventure and nature tours across the country.",
            "I want to bring authentic local food and culture tours to more visitors.",
        };
    }
}
