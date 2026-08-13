namespace Travle.Services.Database.Seeding
{
    /// <summary>
    /// One seeded destination: the city it sits in (matched by name against the geographic upsert), its
    /// category and tags (matched by name against <see cref="SeedTaxonomy"/>), approximate coordinates for
    /// the map, an optional informative on-site entrance fee (KM), and a one-line description.
    /// <see cref="BulkSeeder"/> skips any name that already exists, so the set is safe to re-run.
    /// </summary>
    internal sealed record DestinationSeed(
        string City,
        string Name,
        string Category,
        string[] Tags,
        double Lat,
        double Lng,
        decimal? EntranceFee,
        string Description);

    /// <summary>
    /// The bulk destination catalogue — Bosnia and Herzegovina city by city (fortresses, old towns,
    /// waterfalls, tekije, bridges, mosques/churches and natural sites), plus a handful of flagship sites
    /// across Croatia and the wider Balkans for variety. Coordinates are town-level approximations, adequate
    /// for the map pins.
    /// </summary>
    internal static class SeedDestinations
    {
        public static readonly DestinationSeed[] All =
        {
            // ================= SARAJEVO REGION =================
            new("Sarajevo", "Sebilj Fountain", "Cultural Landmark", ["Ottoman", "Photography", "Bazaar"], 43.8596, 18.4311, null, "The wooden Ottoman-style fountain at the heart of Baščaršija and Sarajevo's best-known landmark."),
            new("Sarajevo", "Gazi Husrev-beg Mosque", "Religious Site", ["Ottoman", "Mosque", "Architecture"], 43.8592, 18.4283, null, "The largest historical mosque in the country, a masterpiece of 16th-century Ottoman architecture."),
            new("Sarajevo", "Sacred Heart Cathedral", "Religious Site", ["Austro-Hungarian", "Church", "Architecture"], 43.8588, 18.4247, null, "Sarajevo's neo-Gothic Catholic cathedral and a symbol of the city."),
            new("Sarajevo", "Latin Bridge", "Bridge", ["Ottoman", "Bridge", "War History"], 43.8578, 18.4290, null, "The Ottoman bridge over the Miljacka where the 1914 assassination that sparked WWI took place."),
            new("Sarajevo", "Sarajevo City Hall (Vijećnica)", "Cultural Landmark", ["Austro-Hungarian", "Architecture", "Museum"], 43.8590, 18.4335, 5.00m, "The pseudo-Moorish former city hall and national library, painstakingly restored after the war."),
            new("Sarajevo", "Yellow Fortress (Žuta Tabija)", "Viewpoint", ["Ottoman", "Fortress", "Panoramic View", "Sunset"], 43.8631, 18.4402, null, "A cannon bastion above the old town with the classic sunset panorama over Sarajevo."),
            new("Sarajevo", "White Fortress (Bijela Tabija)", "Fortress & Castle", ["Ottoman", "Fortress", "Panoramic View"], 43.8639, 18.4432, null, "The medieval-Ottoman fortress crowning the Vratnik walls at the top of the old town."),
            new("Sarajevo", "Tunnel of Hope Museum", "Museum", ["Museum", "War History", "Memorial"], 43.8189, 18.3389, 10.00m, "The hand-dug siege tunnel under the airport runway that kept wartime Sarajevo supplied."),
            new("Sarajevo", "Trebević Mountain", "Mountain & Peak", ["Mountains", "Hiking", "Panoramic View", "Winter"], 43.8339, 18.4472, null, "Sarajevo's home mountain, reached by cable car, with the abandoned 1984 Olympic bobsled track."),
            new("Sarajevo", "Vijećnica Riverside Old Town Walk", "Old Town", ["Old Town", "Ottoman", "Photography"], 43.8585, 18.4300, null, "The historic Ottoman core of coppersmith lanes, mosques, hans and cafés along the Miljacka."),
            new("Ilidža", "Ilidža Spa Promenade", "Park & Garden", ["Austro-Hungarian", "Family Friendly", "Spa & Wellness"], 43.8283, 18.3100, null, "The tree-lined Velika Aleja promenade linking Ilidža's thermal spa to the springs of the Bosna."),
            new("Ilidža", "Roman Bridge on the Bosna", "Bridge", ["Roman", "Bridge", "River"], 43.8225, 18.2947, null, "An Ottoman bridge built from Roman stone at the mouth of the Bosna spring park."),
            new("Hadžići", "Igman Olympic Jumps", "Adventure", ["Mountains", "Winter", "War History"], 43.7561, 18.2833, null, "The dramatic ski-jump ramps from the 1984 Winter Olympics on the slopes of Mount Igman."),
            new("Vogošća", "Bijambare Caves", "Cave", ["Cave", "Nature", "Family Friendly"], 44.0000, 18.3667, 5.00m, "A protected karst area of easy show-caves and forest trails north of Sarajevo."),
            new("Ilijaš", "Bobovac Royal Fortress", "Fortress & Castle", ["Medieval", "Fortress", "Off the Beaten Path"], 44.0847, 18.1653, null, "The ruined seat of the medieval Bosnian kings, hidden in the hills above Ilijaš."),
            new("Trnovo", "Bjelašnica Peak", "Mountain & Peak", ["Mountains", "Hiking", "Skiing", "Winter"], 43.7122, 18.2622, null, "An Olympic ski mountain with high-altitude hiking and the traditional village of Lukomir nearby."),
            new("Trnovo", "Lukomir Highland Village", "Cultural Landmark", ["Mountains", "Traditional Crafts", "Off the Beaten Path"], 43.6633, 18.2331, null, "Bosnia's highest and remotest permanent village, of stone houses on the Bjelašnica plateau."),
            new("Pale", "Jahorina Ski Resort", "Mountain & Peak", ["Mountains", "Skiing", "Winter", "Panoramic View"], 43.7333, 18.5667, null, "The 1984 Olympic ski resort, now the country's biggest winter-sports destination."),

            // ================= CENTRAL BOSNIA (Lašva-Vrbas) =================
            new("Travnik", "Travnik Old Fort (Stari grad)", "Fortress & Castle", ["Medieval", "Fortress", "Ottoman", "Panoramic View"], 44.2306, 17.6700, 3.00m, "The well-preserved medieval fortress above Travnik, once seat of the Bosnian viziers."),
            new("Travnik", "Many-Coloured Mosque (Šarena džamija)", "Religious Site", ["Ottoman", "Mosque", "Architecture"], 44.2264, 17.6706, null, "A rare painted Ottoman mosque with a bazaar built into its raised arcade."),
            new("Travnik", "Plava Voda", "River & Spring", ["Spring", "River", "Family Friendly", "Food"], 44.2286, 17.6750, null, "A shaded spring and stream of restaurants — Travnik's favourite summer gathering spot."),
            new("Vitez", "Bila River Canyon", "Canyon", ["Canyon", "Nature", "Hiking"], 44.1583, 17.7906, null, "A green limestone canyon with trails and swimming holes near Vitez."),
            new("Novi Travnik", "Vlašić Plateau", "Mountain & Peak", ["Mountains", "Skiing", "Winter", "Hiking"], 44.3167, 17.6333, null, "A broad mountain pasture famed for its cheese, skiing and summer hiking."),
            new("Busovača", "Kaonik Fortress", "Fortress & Castle", ["Ottoman", "Fortress", "Off the Beaten Path"], 44.0961, 17.8797, null, "A small Ottoman guard fort at the meeting of the Lašva and Kozica valleys."),
            new("Fojnica", "Franciscan Monastery of Fojnica", "Religious Site", ["Monastery", "Museum", "Medieval"], 43.9633, 17.9033, 3.00m, "A historic Franciscan monastery whose museum holds the famous Ahdname of Mehmed the Conqueror."),
            new("Kiseljak", "Kiseljak Mineral Springs", "River & Spring", ["Spring", "Spa & Wellness", "Family Friendly"], 43.9403, 18.0778, null, "The naturally carbonated mineral springs that gave the town its name and its bottled water."),
            new("Kreševo", "Kreševo Old Craft Town", "Old Town", ["Old Town", "Traditional Crafts", "Ottoman"], 43.8697, 18.0517, null, "A tucked-away town of blacksmiths and a Franciscan monastery in a wooded valley."),
            new("Bugojno", "Source of the Vrbas", "River & Spring", ["Spring", "River", "Nature"], 44.0575, 17.4508, null, "The headwaters of the Vrbas river on the slopes above Bugojno."),
            new("Gornji Vakuf", "Ločika Ski Slopes", "Mountain & Peak", ["Mountains", "Winter", "Skiing"], 43.9375, 17.5847, null, "Family ski slopes on the Radovan plateau above the town."),
            new("Donji Vakuf", "Prusac Fortress & Ajvatovica", "Historical Site", ["Ottoman", "Pilgrimage", "Fortress"], 44.0333, 17.3667, null, "The old town of Prusac and Ajvatovica, the largest Muslim pilgrimage site in Europe."),
            new("Jajce", "Jajce Fortress", "Fortress & Castle", ["Medieval", "Fortress", "Panoramic View"], 44.3419, 17.2708, 3.00m, "The hilltop citadel of the last Bosnian kings, crowning the old town of Jajce."),
            new("Jajce", "Catacombs of Jajce", "Historical Site", ["Medieval", "Off the Beaten Path", "Archaeological Site"], 44.3406, 17.2700, 2.00m, "An unfinished 15th-century underground church carved into the rock beneath the old town."),
            new("Jajce", "Pliva Lakes & Watermills", "Lake", ["Lake", "Nature", "Photography", "Family Friendly"], 44.3339, 17.2394, null, "Two linked lakes on the Pliva lined by a cluster of tiny wooden watermills."),

            // ================= ZENICA & THE BOSNA VALLEY =================
            new("Zenica", "Vranduk Village & Gorge", "Historical Site", ["Medieval", "River", "Off the Beaten Path"], 44.2822, 17.9772, null, "The fortified medieval village guarding the Bosna gorge just north of Zenica."),
            new("Zenica", "Synagogue of Zenica", "Museum", ["Synagogue", "Museum", "Architecture"], 44.2011, 17.9061, 2.00m, "One of Bosnia's few surviving synagogues, now the city museum."),
            new("Zenica", "Smetovi Recreation Area", "Mountain & Peak", ["Mountains", "Hiking", "Winter", "Panoramic View"], 44.2333, 17.9500, null, "A forested ridge above Zenica with trails, ski runs and city views."),
            new("Kakanj", "Kraljeva Sutjeska", "Religious Site", ["Medieval", "Monastery", "Off the Beaten Path"], 44.1706, 18.0900, null, "The royal town of the medieval Bosnian kings, with an old Franciscan monastery and the oldest mosque of the region."),
            new("Visoko", "Visočica Hill (Pyramid of the Sun)", "Mountain & Peak", ["Hiking", "Panoramic View", "Off the Beaten Path"], 43.9789, 18.1758, null, "The pyramid-shaped hill above Visoko, a curiosity that draws visitors from around the world."),
            new("Visoko", "Old Town of Visoki", "Archaeological Site", ["Medieval", "Archaeological Site", "Panoramic View"], 43.9906, 18.1794, null, "The ruined royal fortress of Visoki, cradle of the medieval Bosnian state."),
            new("Breza", "Roman Basilica of Breza", "Archaeological Site", ["Roman", "Archaeological Site", "Off the Beaten Path"], 44.0208, 18.2603, null, "The remains of a late-antique Roman basilica with rare carved ornament."),
            new("Vareš", "Old Town of Bobovac Approach", "Historical Site", ["Medieval", "Hiking", "Off the Beaten Path"], 44.1636, 18.3267, null, "The forested trail from Vareš up to the royal fortress-tombs of Bobovac."),
            new("Olovo", "Olovo Thermal Spa", "River & Spring", ["Spa & Wellness", "Nature", "Family Friendly"], 44.1281, 18.5867, null, "A pine-scented thermal spa town long known for its healing waters."),
            new("Žepče", "Žepče Old Fort", "Fortress & Castle", ["Ottoman", "Fortress", "Off the Beaten Path"], 44.4283, 18.0356, null, "The remnants of an Ottoman fort above the Bosna at Žepče."),
            new("Zavidovići", "Tajan Nature Park", "National Park", ["Nature", "Canyon", "Hiking", "Waterfall"], 44.3833, 18.2000, null, "A wild protected area of canyons, waterfalls and old-growth forest on the Tajan massif."),
            new("Maglaj", "Maglaj Fortress", "Fortress & Castle", ["Medieval", "Fortress", "River"], 44.5461, 18.1006, null, "A compact medieval fortress overlooking the Bosna and the old town of Maglaj."),
            new("Tešanj", "Tešanj Fortress", "Fortress & Castle", ["Medieval", "Fortress", "Panoramic View"], 44.6136, 17.9856, 2.00m, "One of the largest and best-preserved fortresses in Bosnia, towering over the old town of Tešanj."),
            new("Tešanj", "Tešanj Old Bazaar", "Old Town", ["Old Town", "Ottoman", "Traditional Crafts"], 44.6122, 17.9847, null, "The compact Ottoman čaršija below the fortress, still full of small workshops."),

            // ================= BOSANSKA KRAJINA (Una-Sana) =================
            new("Bihać", "Fethija Mosque", "Religious Site", ["Ottoman", "Mosque", "Architecture"], 44.8147, 15.8686, null, "A rare mosque converted from a Gothic church, in the heart of Bihać's old town."),
            new("Bihać", "Captain's Tower (Kapetanova kula)", "Museum", ["Medieval", "Museum", "River"], 44.8156, 15.8697, 2.00m, "A medieval stone tower on the Una, now the town museum of Bihać."),
            new("Bihać", "Štrbački Buk", "Waterfall", ["Waterfall", "River", "Rafting", "Photography"], 44.6461, 16.1567, 8.00m, "The mighty 24-metre waterfall of the Una, the crown jewel of the national park."),
            new("Bihać", "Japodski Otoci", "River & Spring", ["River", "Swimming", "Family Friendly"], 44.7869, 15.8642, null, "River islands and thermal springs on the Una, a favourite bathing spot near Bihać."),
            new("Bihać", "Martin Brod Waterfalls", "Waterfall", ["Waterfall", "River", "Nature", "Photography"], 44.4708, 16.1417, 8.00m, "A cascading complex of tufa waterfalls where the Unac joins the Una."),
            new("Bihać", "Kostelski Buk", "Waterfall", ["Waterfall", "River", "Swimming"], 44.7286, 16.0272, null, "A wide waterfall and mill-race on the Una, with a riverside restaurant."),
            new("Bihać", "Sokolac Fortress", "Fortress & Castle", ["Medieval", "Fortress", "Off the Beaten Path"], 44.8517, 15.9083, null, "A medieval fortress of the Bihać captains, on a hill above the Una valley."),
            new("Cazin", "Ostrožac Old Craft Fair", "Cultural Landmark", ["Medieval", "Traditional Crafts", "Fortress"], 44.9203, 15.9797, null, "The dramatic layered castle of Ostrožac and its summer sculpture-and-craft gatherings."),
            new("Cazin", "Cazin Old Town", "Old Town", ["Old Town", "Ottoman", "Off the Beaten Path"], 44.9686, 15.9436, null, "The historic core of Cazin with its old fort and čaršija."),
            new("Velika Kladuša", "Velika Kladuša Castle", "Fortress & Castle", ["Medieval", "Fortress"], 45.1836, 15.8072, null, "The old town fortress of the Kladuša counts, on a rise above the town."),
            new("Bosanska Krupa", "Krupa Island & Old Town", "Old Town", ["River", "Old Town", "Family Friendly"], 44.8828, 16.1519, null, "The Una splits around a wooded island beneath Bosanska Krupa's old fort."),
            new("Bužim", "Bužim Fortress", "Fortress & Castle", ["Medieval", "Fortress", "Off the Beaten Path"], 45.0500, 16.0300, null, "A well-preserved medieval fortress that resisted long Ottoman sieges."),
            new("Sanski Most", "Blihe Waterfall (Blihanski slap)", "Waterfall", ["Waterfall", "Nature", "Off the Beaten Path"], 44.7100, 16.5900, null, "A tall thin waterfall dropping into the wooded valley near Sanski Most."),
            new("Ključ", "Ključ Fortress", "Fortress & Castle", ["Medieval", "Fortress", "Panoramic View"], 44.5333, 16.7767, null, "The clifftop fortress where the last Bosnian king was captured in 1463."),
            new("Bosanski Petrovac", "Petrovac Uvala Karst Field", "Natural Wonder", ["Nature", "Off the Beaten Path", "Cycling"], 44.5500, 16.3600, null, "The wide karst plain and cave country around Bosanski Petrovac."),
            new("Drvar", "Drvar Cave (Titova pećina)", "Cave", ["Cave", "War History", "Nature"], 44.3722, 16.3831, null, "A river-mouth cave above Drvar, the famous wartime headquarters of Tito."),
            new("Prijedor", "Kozara National Park", "National Park", ["National Park", "Nature", "Memorial", "Hiking"], 44.9667, 16.9333, null, "A forested mountain national park with a monumental WWII memorial on Mrakovica peak."),
            new("Prijedor", "Old Town of Prijedor", "Old Town", ["Old Town", "Ottoman", "River"], 44.9797, 16.7147, null, "The riverside old core of Prijedor on the Sana, with its historic town mosque."),
            new("Bosanski Novi", "Confluence of the Una and Sana", "River & Spring", ["River", "Swimming", "Family Friendly"], 45.0500, 16.3800, null, "The green meeting of the Una and Sana rivers at Bosanski Novi, a bathing and fishing spot."),
            new("Bosanska Dubica", "Moštanica Monastery", "Religious Site", ["Monastery", "Off the Beaten Path"], 45.1000, 16.7500, null, "A historic Orthodox monastery in the wooded hills of Kozara near Bosanska Dubica."),

            // ================= LIVNO REGION =================
            new("Livno", "Livno Wild Horses", "Natural Wonder", ["Wildlife", "Nature", "Photography"], 43.9333, 16.9333, null, "Hundreds of free-roaming wild horses on the Kruzi plateau above Livno."),
            new("Livno", "Gorica Franciscan Monastery", "Museum", ["Monastery", "Museum", "Architecture"], 43.8269, 17.0078, 3.00m, "A Franciscan monastery and gallery overlooking Livno, with an important art collection."),
            new("Livno", "Bistrica Springs", "River & Spring", ["Spring", "River", "Nature"], 43.8300, 17.0200, null, "The karst springs of the Bistrica that feed the Livanjsko polje."),
            new("Duvno", "Blidinje Nature Park", "National Park", ["National Park", "Mountains", "Hiking", "Skiing"], 43.6333, 17.5333, null, "A high plateau nature park between the Čvrsnica and Vran mountains, with stećci and ski slopes."),
            new("Duvno", "Stećci of Dugo Polje", "Archaeological Site", ["Stećci", "UNESCO", "Medieval"], 43.6389, 17.5500, null, "A UNESCO-listed field of medieval carved tombstones on the Blidinje plateau."),
            new("Kupres", "Kupres Ski Resort", "Mountain & Peak", ["Mountains", "Skiing", "Winter"], 43.9944, 17.2794, null, "A high, snow-sure plateau resort popular for skiing and highland horse-riding."),
            new("Glamoč", "Glamoč Karst Field", "Natural Wonder", ["Nature", "Off the Beaten Path", "Wildlife"], 44.0500, 16.8500, null, "One of the largest karst poljes in the Dinarides, ringed by mountains."),
            new("Bosansko Grahovo", "Preodac Karst Spring", "River & Spring", ["Spring", "Nature", "Off the Beaten Path"], 44.1800, 16.3600, null, "A powerful karst spring in the remote highlands around Bosansko Grahovo."),

            // ================= WEST HERZEGOVINA =================
            new("Široki Brijeg", "Franciscan Monastery of Široki Brijeg", "Religious Site", ["Monastery", "Architecture", "Church"], 43.3833, 17.5928, null, "A landmark hilltop Franciscan monastery and church at the centre of the town."),
            new("Široki Brijeg", "Borak Lake", "Lake", ["Lake", "Swimming", "Family Friendly"], 43.3700, 17.6000, null, "A green reservoir lake on the edge of Široki Brijeg, popular for summer swimming."),
            new("Ljubuški", "Kravice-Koćuša Waterfall", "Waterfall", ["Waterfall", "River", "Swimming", "Nature"], 43.1611, 17.6486, null, "The wide horseshoe waterfall of Koćuša on the Trebižat, quieter sibling of Kravice."),
            new("Ljubuški", "Herceg Stjepan Fort (Ljubuški)", "Fortress & Castle", ["Medieval", "Fortress", "Panoramic View"], 43.2019, 17.5461, null, "A medieval hilltop fortress with sweeping views over the Ljubuški vineyards."),
            new("Ljubuški", "Vjetrenica Vineyards & Wine Road", "Cultural Landmark", ["Wine", "Food", "Traditional Crafts"], 43.1961, 17.5461, null, "The sun-soaked vineyards and cellars of the Ljubuški wine road."),
            new("Grude", "Peć Mlini Cave & Springs", "Cave", ["Cave", "Spring", "River"], 43.3706, 17.4139, null, "A show-cave and karst spring where an underground river surfaces near Grude."),
            new("Posušje", "Tribistovo Lake", "Lake", ["Lake", "Nature", "Off the Beaten Path"], 43.4728, 17.3308, null, "A high mountain lake above Posušje, a peaceful spot for walking and picnics."),

            // ================= CENTRAL HERZEGOVINA =================
            new("Mostar", "Koski Mehmed-Pasha Mosque", "Religious Site", ["Ottoman", "Mosque", "Panoramic View"], 43.3389, 17.8156, 4.00m, "A riverside Ottoman mosque whose minaret gives the classic postcard view of the Old Bridge."),
            new("Mostar", "Crooked Bridge (Kriva ćuprija)", "Bridge", ["Ottoman", "Bridge", "Photography"], 43.3369, 17.8144, null, "A small arched Ottoman bridge, a miniature forerunner of the famous Stari Most."),
            new("Mostar", "Old Bazaar (Kujundžiluk)", "Old Town", ["Ottoman", "Bazaar", "Old Town", "Traditional Crafts"], 43.3375, 17.8153, null, "The cobbled coppersmith bazaar of Mostar's old town beside the Neretva."),
            new("Mostar", "Partisan Memorial Cemetery", "Monument & Memorial", ["Memorial", "Architecture", "Off the Beaten Path"], 43.3467, 17.8025, null, "A vast modernist WWII memorial complex by architect Bogdan Bogdanović."),
            new("Konjic", "Old Stone Bridge of Konjic", "Bridge", ["Ottoman", "Bridge", "River"], 43.6519, 17.9614, null, "A six-arched Ottoman bridge over the emerald Neretva in the centre of Konjic."),
            new("Konjic", "Tito's Nuclear Bunker (ARK D-0)", "Museum", ["Museum", "War History", "Off the Beaten Path"], 43.6394, 17.9500, 15.00m, "A vast secret Cold-War nuclear bunker, now an extraordinary underground art space."),
            new("Konjic", "Boračko Lake", "Lake", ["Lake", "Swimming", "Nature", "Family Friendly"], 43.5967, 18.0333, null, "A clear glacial lake below the Prenj and Bjelašnica mountains, a popular swimming and rafting base."),
            new("Jablanica", "Battle of the Neretva Museum", "Museum", ["Museum", "War History", "Memorial"], 43.6603, 17.7611, 3.00m, "The museum and famous destroyed railway bridge of the 1943 Battle of the Neretva."),
            new("Jablanica", "Jablaničko Lake", "Lake", ["Lake", "Swimming", "Photography"], 43.7000, 17.7500, null, "A long turquoise reservoir along the Neretva, lined with lakeside restaurants."),
            new("Čapljina", "Hutovo Blato Nature Park", "National Park", ["National Park", "Wildlife", "Nature", "Photography"], 43.0500, 17.7500, 10.00m, "A birdwatchers' wetland of lakes and reed beds on the lower Neretva."),
            new("Čapljina", "Počitelj Viewpoint Trail", "Viewpoint", ["Panoramic View", "Ottoman", "Hiking"], 43.1300, 17.7367, null, "The ridge path above the Neretva with the classic view of the stepped town of Počitelj."),
            new("Stolac", "Radimlja Necropolis", "Archaeological Site", ["Stećci", "UNESCO", "Medieval"], 43.0872, 17.9297, 3.00m, "The most famous field of medieval stećci tombstones, carved with knights and dancers."),
            new("Stolac", "Vidoški Fortress", "Fortress & Castle", ["Medieval", "Fortress", "Panoramic View"], 43.0847, 17.9578, null, "A large medieval-Ottoman fortress on the hill above the old town of Stolac."),
            new("Stolac", "Begovina Old Quarter", "Old Town", ["Old Town", "Ottoman", "Architecture"], 43.0844, 17.9556, null, "A preserved quarter of Ottoman-era stone residences and gardens in Stolac."),
            new("Čitluk", "Međugorje Sanctuary", "Religious Site", ["Pilgrimage", "Church", "Family Friendly"], 43.1908, 17.6764, null, "The world-famous Catholic pilgrimage site of St. James's church and Apparition Hill."),
            new("Neum", "Neum Riviera", "Natural Wonder", ["Swimming", "Family Friendly", "Sunset"], 42.9236, 17.6156, null, "Bosnia and Herzegovina's only stretch of Adriatic coast, a small sunny resort bay."),

            // ================= EAST HERZEGOVINA =================
            new("Trebinje", "Arslanagić Bridge", "Bridge", ["Ottoman", "Bridge", "River"], 42.7150, 18.3419, null, "A graceful twin-arched Ottoman bridge over the Trebišnjica in Trebinje."),
            new("Trebinje", "Hercegovačka Gračanica", "Religious Site", ["Church", "Monastery", "Panoramic View"], 42.7089, 18.3500, null, "A hilltop replica of the medieval Gračanica monastery, with the tomb of poet Jovan Dučić and wide views over Trebinje."),
            new("Trebinje", "Trebinje Old Town & Osman-paša Mosque", "Old Town", ["Old Town", "Ottoman", "Mosque"], 42.7113, 18.3444, null, "The walled Ottoman old town of Trebinje shaded by giant plane trees."),
            new("Trebinje", "Vjetrenica Cave", "Cave", ["Cave", "Nature", "Wildlife"], 42.8900, 17.9900, 12.00m, "The largest cave in Bosnia and Herzegovina, richest in cave life in the world."),
            new("Bileća", "Bileća Lake", "Lake", ["Lake", "Swimming", "Photography"], 42.8722, 18.4289, null, "A vast turquoise reservoir in the Herzegovinian karst, ringed by bare hills."),
            new("Gacko", "Gatačko Polje & Old Herzegovina", "Natural Wonder", ["Nature", "Off the Beaten Path", "Wildlife"], 43.1678, 18.5350, null, "A high karst plain of grazing herds and stone hamlets in old Herzegovina."),
            new("Nevesinje", "Odžak Fortress", "Fortress & Castle", ["Medieval", "Fortress", "Off the Beaten Path"], 43.2589, 18.1128, null, "A ruined medieval fortress on the edge of the Nevesinje field."),
            new("Ljubinje", "Žitomislić Monastery Road", "Religious Site", ["Monastery", "Off the Beaten Path"], 42.9508, 18.0894, null, "The old road linking Ljubinje to the historic monasteries of the Neretva canyon."),
            new("Berkovići", "Dabar Cave & Field", "Cave", ["Cave", "Nature", "Off the Beaten Path"], 43.0500, 18.1500, null, "A karst field and cave system in the remote uplands of Berkovići."),

            // ================= NORTH BOSNIA (Posavina & Banja Luka-Doboj) =================
            new("Banja Luka", "Kastel Fortress", "Fortress & Castle", ["Roman", "Fortress", "River", "Medieval"], 44.7583, 17.1836, null, "The great riverside fortress of Banja Luka, with Roman and medieval layers, on the Vrbas."),
            new("Banja Luka", "Ferhat Pasha Mosque (Ferhadija)", "Religious Site", ["Ottoman", "Mosque", "UNESCO"], 44.7714, 17.1897, null, "A 16th-century masterpiece mosque, destroyed in the war and rebuilt stone by stone."),
            new("Banja Luka", "Christ the Saviour Cathedral", "Religious Site", ["Church", "Architecture"], 44.7719, 17.1908, null, "The distinctive coloured-stone Orthodox cathedral in the centre of Banja Luka."),
            new("Banja Luka", "Krupa na Vrbasu Waterfalls", "Waterfall", ["Waterfall", "River", "Nature", "Photography"], 44.6100, 17.2400, null, "The tufa cascades of the Krupa river beside an old Orthodox monastery, south of Banja Luka."),
            new("Banja Luka", "Vrbas Canyon & Rafting", "Canyon", ["Canyon", "Rafting", "River", "Adventure"], 44.6300, 17.2600, null, "The dramatic Tijesno gorge of the Vrbas above Banja Luka, Bosnia's premier white-water rafting run."),
            new("Laktaši", "Laktaši Thermal Spa", "River & Spring", ["Spa & Wellness", "Family Friendly"], 44.9061, 17.3006, null, "A well-known thermal-water spa and pools resort north of Banja Luka."),
            new("Bosanska Gradiška", "Bosanska Gradiška Danube-Sava Lowlands", "Natural Wonder", ["Nature", "River", "Cycling"], 45.1442, 17.2544, null, "The flat riverine border country of the Sava around Gradiška, good for cycling."),
            new("Prnjavor", "Nova Topola Historic Colony", "Cultural Landmark", ["Austro-Hungarian", "Off the Beaten Path"], 44.9000, 17.5000, null, "A 19th-century planned settler village of the Austro-Hungarian era near Prnjavor."),
            new("Srbac", "Confluence of the Vrbas and Sava", "River & Spring", ["River", "Wildlife", "Nature"], 45.0967, 17.5250, null, "The wide meeting of the Vrbas and Sava, a wetland rich in birds near Srbac."),
            new("Čelinac", "Tijesno Canyon of the Vrbanja", "Canyon", ["Canyon", "River", "Swimming"], 44.7267, 17.3247, null, "A narrow, green rock canyon on the Vrbanja river near Čelinac."),
            new("Kotor Varoš", "Kotor Varoš Old Fort", "Fortress & Castle", ["Medieval", "Fortress", "Off the Beaten Path"], 44.6178, 17.3719, null, "The remains of a medieval fort above the confluence town of Kotor Varoš."),
            new("Teslić", "Banja Vrućica Spa", "River & Spring", ["Spa & Wellness", "Nature", "Family Friendly"], 44.6089, 17.8592, null, "One of the largest thermal-spa resorts in the country, set in wooded hills near Teslić."),
            new("Mrkonjić Grad", "Old Town of Mrkonjić (Zvečaj)", "Fortress & Castle", ["Medieval", "Fortress"], 44.4158, 17.0872, null, "The medieval fortress ruins associated with the Bosnian king Stjepan Tomašević."),
            new("Šipovo", "Pliva River Springs", "River & Spring", ["Spring", "River", "Nature"], 44.2839, 17.0864, null, "The clear karst springs where the Pliva river rises near Šipovo."),
            new("Jezero", "Plivsko Lake at Jezero", "Lake", ["Lake", "Nature", "Family Friendly"], 44.3500, 17.2500, null, "The upper Pliva lake beside the village of Jezero, a calm spot for boating."),
            new("Skender Vakuf", "Smetovi-Skender Vakuf Highlands", "Mountain & Peak", ["Mountains", "Hiking", "Off the Beaten Path"], 44.4933, 17.3811, null, "The forested Čemernica highlands above Skender Vakuf, good for walking and berry-picking."),
            new("Doboj", "Doboj Fortress (Gradina)", "Fortress & Castle", ["Medieval", "Fortress", "Panoramic View"], 44.7350, 18.0864, 2.00m, "A large well-restored medieval fortress commanding the Bosna and Spreča valleys."),
            new("Derventa", "Derventa Town Museum", "Museum", ["Museum", "Austro-Hungarian"], 44.9769, 17.9147, null, "The local heritage museum of the Posavina town of Derventa."),
            new("Modriča", "Modriča Bosna Riverside", "River & Spring", ["River", "Family Friendly", "Cycling"], 44.9569, 18.3006, null, "The riverside parks and paths along the lower Bosna at Modriča."),
            new("Bosanski Šamac", "Sava River Port of Bosanski Šamac", "Cultural Landmark", ["River", "Off the Beaten Path"], 45.0603, 18.4700, null, "The border river port on the Sava, gateway between Bosnia and Slavonia."),
            new("Odžak", "Odžak Posavina Wetlands", "Natural Wonder", ["Nature", "Wildlife", "River"], 45.0142, 18.3222, null, "Floodplain wetlands and fishing waters of the Sava basin around Odžak."),
            new("Orašje", "Orašje Sava Embankment", "Cultural Landmark", ["River", "Family Friendly"], 45.0378, 18.6939, null, "The riverside promenade of the northernmost town in the country, on the Sava."),
            new("Bosanski Brod", "Bosanski Brod Sava Bridge & Old Quarter", "Cultural Landmark", ["River", "Austro-Hungarian", "Off the Beaten Path"], 45.1394, 17.9992, null, "The border-bridge town on the Sava, with an old industrial-era quarter."),
            new("Bosansko Petrovo Selo", "Ozren Monastery", "Religious Site", ["Monastery", "Nature", "Off the Beaten Path"], 44.6200, 18.3600, null, "A historic Orthodox monastery on the wooded slopes of Mount Ozren."),

            // ================= NORTHEAST BOSNIA (Tuzla & Semberija) =================
            new("Tuzla", "Pannonian Salt Lakes", "Lake", ["Lake", "Swimming", "Family Friendly", "Spa & Wellness"], 44.5386, 18.6764, 5.00m, "Man-made saltwater lakes in the city centre — a unique inland seaside made from Tuzla's salt heritage."),
            new("Tuzla", "Kapija Square & Old Town", "Old Town", ["Old Town", "Ottoman", "Memorial"], 44.5386, 18.6764, null, "Tuzla's lively main square, its Ottoman core and the moving Kapija memorial."),
            new("Tuzla", "Salt Museum & Turkish Baths", "Museum", ["Museum", "Ottoman", "Traditional Crafts"], 44.5389, 18.6772, 2.00m, "The story of Tuzla's ancient salt-making, beside a restored Ottoman hammam."),
            new("Lukavac", "Modrac Lake", "Lake", ["Lake", "Swimming", "Family Friendly"], 44.5000, 18.5500, null, "The largest artificial lake in Bosnia, a summer watersports and swimming spot near Lukavac."),
            new("Živinice", "Konjuh Mountain", "Mountain & Peak", ["Mountains", "Hiking", "Nature"], 44.3000, 18.7000, null, "A forested mountain of trails and clearings rising above Živinice."),
            new("Banovići", "Banovići Forest Railway", "Cultural Landmark", ["Traditional Crafts", "Family Friendly", "Off the Beaten Path"], 44.4058, 18.5261, 10.00m, "A working narrow-gauge steam railway through the coal-country forests of Banovići."),
            new("Gračanica", "Gradina of Soko (Gračanica)", "Fortress & Castle", ["Medieval", "Fortress", "Panoramic View"], 44.7028, 18.3103, null, "A hilltop medieval fortress above the old bazaar town of Gračanica."),
            new("Gradačac", "Gradačac Fortress (Zmaj od Bosne)", "Fortress & Castle", ["Ottoman", "Fortress", "Panoramic View"], 44.8783, 18.4267, 2.00m, "The tower and walls of Husein-kapetan Gradaščević, the 'Dragon of Bosnia'."),
            new("Kalesija", "Kalesija Bazaar Town", "Old Town", ["Old Town", "Ottoman", "Off the Beaten Path"], 44.5556, 18.9161, null, "A small market town on the road to the Drina, with its old town mosque."),
            new("Sapna", "Zeleni Vir Sapna", "River & Spring", ["Spring", "Nature", "Family Friendly"], 44.5000, 18.9800, null, "A green karst spring and picnic area in the hills of Sapna."),
            new("Lopare", "Majevica Mountain Trails", "Mountain & Peak", ["Mountains", "Hiking", "Nature"], 44.6461, 18.8461, null, "The wooded ridges of Majevica above Lopare, criss-crossed with walking trails."),
            new("Ugljevik", "Ugljevik Lake & Uplands", "Lake", ["Lake", "Nature", "Off the Beaten Path"], 44.6858, 19.0025, null, "A reservoir lake and quiet uplands in the coal country of Ugljevik."),
            new("Bijeljina", "Semberija Ethno Village Stanišić", "Cultural Landmark", ["Traditional Crafts", "Family Friendly", "Food"], 44.7589, 19.2144, 5.00m, "A recreated Semberija village of old wooden houses, a church and a lake near Bijeljina."),
            new("Bijeljina", "Tavna Monastery", "Religious Site", ["Monastery", "Medieval", "Off the Beaten Path"], 44.6000, 19.1000, null, "A medieval Orthodox monastery hidden in the wooded hills south of Bijeljina."),
            new("Zvornik", "Zvornik Fortress (Đurđev grad)", "Fortress & Castle", ["Medieval", "Fortress", "River"], 44.3861, 19.1022, null, "A long medieval fortress climbing the hillside above the Drina at Zvornik."),
            new("Kladanj", "Sixth Blue Water (Muška voda)", "River & Spring", ["Spring", "Nature", "Family Friendly"], 44.2264, 18.6919, null, "A forest spring and picnic resort long famed for its healing waters near Kladanj."),

            // ================= EAST BOSNIA (Podrinje) =================
            new("Foča", "Tara River Canyon (Foča)", "Canyon", ["Canyon", "Rafting", "River", "Adventure"], 43.3400, 18.8500, null, "The deepest river canyon in Europe, where rafting trips launch from Šćepan Polje near Foča."),
            new("Foča", "Sutjeska National Park & Maglić", "National Park", ["National Park", "Mountains", "Hiking", "Memorial"], 43.3333, 18.7000, null, "Bosnia's oldest national park, home to Perućica virgin forest and the country's highest peak, Maglić."),
            new("Foča", "Aladža Mosque", "Religious Site", ["Ottoman", "Mosque", "Architecture"], 43.5058, 18.7789, null, "A finely painted 16th-century Ottoman mosque, rebuilt after wartime destruction."),
            new("Goražde", "Goražde Old Bridge & Drina", "Bridge", ["Bridge", "River", "Family Friendly"], 43.6672, 18.9764, null, "The bridges and riverside promenade of Goražde on the emerald Drina."),
            new("Višegrad", "Mehmed Paša Sokolović Bridge", "Bridge", ["Ottoman", "Bridge", "UNESCO", "River"], 43.7828, 19.2861, null, "The UNESCO-listed 16th-century bridge immortalised in Ivo Andrić's Nobel-winning novel."),
            new("Višegrad", "Andrićgrad", "Cultural Landmark", ["Architecture", "Photography", "Family Friendly"], 43.7833, 19.2894, null, "A stone-built theme town by film-maker Emir Kusturica at the meeting of the Drina and Rzav."),
            new("Višegrad", "Višegradska Banja & Dobrun Monastery", "Religious Site", ["Monastery", "Spa & Wellness", "Medieval"], 43.7500, 19.4000, null, "A thermal spa and the frescoed medieval Dobrun monastery in the Rzav valley."),
            new("Rudo", "Sopotnica Waterfalls", "Waterfall", ["Waterfall", "Nature", "Off the Beaten Path"], 43.3000, 19.4000, null, "A series of tufa waterfalls tumbling through the forest near Rudo."),
            new("Čajniče", "Čajniče Monastery", "Religious Site", ["Monastery", "Medieval", "Off the Beaten Path"], 43.5567, 19.0714, null, "An old Orthodox monastery holding a venerated icon, above the town of Čajniče."),
            new("Rogatica", "Old Town of Borač", "Fortress & Castle", ["Medieval", "Fortress", "Off the Beaten Path"], 43.7969, 19.0006, null, "The ruined 'Herzegovinian Troy', a great medieval fortress in the hills near Rogatica."),
            new("Sokolac", "Novi Grad Sokolac Highlands", "Mountain & Peak", ["Mountains", "Nature", "Winter"], 43.9394, 18.8067, null, "The high Glasinac plateau around Sokolac, rich in prehistoric burial mounds."),
            new("Han Pijesak", "Han Pijesak Forest Reserve", "National Park", ["Nature", "Hiking", "Wildlife"], 44.0817, 18.9506, null, "Dense conifer forests and a preserved old-growth reserve high above Han Pijesak."),
            new("Vlasenica", "Tišća Gorge", "Canyon", ["Canyon", "River", "Off the Beaten Path"], 44.1817, 18.9422, null, "A rocky river gorge on the road between Vlasenica and Kladanj."),
            new("Milići", "Derventa Waterfall (Milići)", "Waterfall", ["Waterfall", "Nature", "Off the Beaten Path"], 44.1667, 19.0833, null, "A hidden forest waterfall in the wooded hills of Milići."),
            new("Šekovići", "Lovnica Monastery", "Religious Site", ["Monastery", "Medieval", "Architecture"], 44.2900, 18.9900, null, "A frescoed 16th-century Orthodox monastery in a green valley near Šekovići."),
            new("Srebrenica", "Srebrenica-Potočari Memorial", "Monument & Memorial", ["Memorial", "War History"], 44.1750, 19.2950, null, "The memorial centre and cemetery at Potočari commemorating the victims of the 1995 genocide."),
            new("Srebrenica", "Guber Spa Springs", "River & Spring", ["Spring", "Spa & Wellness", "Nature"], 44.1061, 19.2969, null, "The historic iron-rich mineral springs above the town of Srebrenica."),
            new("Bratunac", "Drina Riverside at Bratunac", "River & Spring", ["River", "Family Friendly", "Cycling"], 44.1897, 19.3339, null, "The green banks of the Drina at Bratunac, a spot for fishing and riverside walks."),

            // ================= ICONIC LANDMARKS (the most-visited sites of the country) =================
            new("Mostar", "Stari Most", "Bridge", ["UNESCO", "Ottoman", "Bridge", "Old Town", "Photography"], 43.3373, 17.8149, null, "The iconic rebuilt 16th-century Ottoman bridge over the Neretva — a UNESCO World Heritage Site and the very symbol of Mostar."),
            new("Sarajevo", "Baščaršija", "Old Town", ["Ottoman", "Bazaar", "Old Town", "Architecture", "Photography"], 43.8595, 18.4310, null, "Sarajevo's 15th-century Ottoman bazaar and cultural heart, full of coppersmiths, mosques and cafés."),
            new("Ilidža", "Vrelo Bosne", "River & Spring", ["Nature", "River", "Spring", "Family Friendly"], 43.8206, 18.2725, 2.00m, "The landscaped park at the spring of the river Bosna at the foot of Mount Igman, reached by a fiaker ride down Velika Aleja."),
            new("Ljubuški", "Kravice Waterfalls", "Waterfall", ["Waterfall", "River", "Swimming", "Nature", "Photography"], 43.1583, 17.6000, 10.00m, "A wide natural amphitheatre of waterfalls on the Trebižat, a favourite spot for swimming on a hot summer day."),
            new("Blagaj", "Blagaj Tekija", "Religious Site", ["Ottoman", "Pilgrimage", "River", "Spring"], 43.2570, 17.8880, 4.00m, "A 16th-century dervish monastery built against a cliff at the turquoise source of the Buna river."),
            new("Počitelj", "Počitelj Fortified Town", "Old Town", ["Ottoman", "Old Town", "Fortress", "Architecture"], 43.1300, 17.7300, null, "A stepped Ottoman-era fortress village cascading down the hillside above the Neretva valley."),
            new("Jajce", "Jajce Waterfall", "Waterfall", ["Waterfall", "River", "Nature", "Photography"], 44.3400, 17.2700, 6.00m, "The 20-metre waterfall where the Pliva plunges into the Vrbas in the very centre of Jajce."),
            new("Bihać", "Una National Park", "National Park", ["National Park", "River", "Rafting", "Nature", "Waterfall"], 44.6500, 16.1500, 15.00m, "Protected river canyons, rapids and waterfalls of the upper Una — Bosnia's rafting heartland."),
            new("Srebrenik", "Srebrenik Fortress", "Fortress & Castle", ["Medieval", "Fortress", "Panoramic View"], 44.7000, 18.4900, 2.00m, "A 13th-century fortress on a dramatic rock spur, reached by a bridge over a chasm — one of the best-preserved in Bosnia."),
            new("Prozor", "Ramsko Lake & Šćit Monastery", "Lake", ["Lake", "Nature", "Monastery", "Family Friendly"], 43.7900, 17.6600, null, "A turquoise mountain reservoir with a Franciscan monastery on the Šćit peninsula, in the Rama valley."),

            // ================= FLAGSHIP DESTINATIONS ABROAD =================
            new("Dubrovnik", "Dubrovnik City Walls", "Old Town", ["UNESCO", "Old Town", "Panoramic View", "Architecture"], 42.6414, 18.1075, 35.00m, "The magnificent walled old town of Dubrovnik, the 'Pearl of the Adriatic'."),
            new("Korenica", "Plitvice Lakes", "National Park", ["National Park", "Waterfall", "Lake", "UNESCO"], 44.8654, 15.5820, 40.00m, "Croatia's most famous national park, a staircase of turquoise lakes and waterfalls."),
            new("Šibenik", "Krka National Park", "National Park", ["National Park", "Waterfall", "River", "Swimming"], 43.8064, 15.9633, 30.00m, "The travertine waterfalls of the Krka river, a short trip inland from Šibenik."),
            new("Kotor", "Bay of Kotor & Old Town", "Old Town", ["UNESCO", "Old Town", "Panoramic View", "Sunset"], 42.4247, 18.7712, 15.00m, "A fjord-like bay and a walled medieval town climbing the mountainside in Montenegro."),
            new("Ohrid", "Lake Ohrid & Old Town", "Lake", ["UNESCO", "Lake", "Old Town", "Church"], 41.1231, 20.8016, null, "One of Europe's oldest and deepest lakes, ringed by ancient churches in North Macedonia."),
            new("Belgrade", "Belgrade Fortress (Kalemegdan)", "Fortress & Castle", ["Fortress", "River", "Panoramic View"], 44.8225, 20.4508, null, "The great fortress park at the meeting of the Sava and Danube in the Serbian capital."),
            new("Mecca", "Kaaba & Grand Mosque", "Religious Site", ["Pilgrimage", "Mosque", "Architecture"], 21.4225, 39.8262, null, "The holiest site in Islam and the destination of the Hajj pilgrimage."),
            new("Istanbul", "Hagia Sophia", "Religious Site", ["UNESCO", "Architecture", "Museum"], 41.0086, 28.9800, null, "The awe-inspiring Byzantine-Ottoman monument at the heart of old Istanbul."),
            new("Sarajevo", "Bosnian Coffee & Ćevabdžinica Trail", "Cultural Landmark", ["Food", "Traditional Crafts", "Bazaar"], 43.8593, 18.4290, null, "A tasting walk through Baščaršija's ćevabdžinice and traditional Bosnian coffee houses."),
        };
    }
}
