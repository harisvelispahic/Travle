# Dokumentacija sistema za preporuke

**Projekt:** Travle — platforma za otkrivanje turističkih destinacija i rezervaciju tura
**Predmet:** Razvoj softvera II
**Fakultet:** Fakultet informacijskih tehnologija (FIT)
**Akademska godina:** 2025/2026
**Broj indeksa:** IB230172

---

## 1. Uvod

Ovaj dokument opisuje dizajn, implementaciju i način rada sistema za preporuke ugrađenog u platformu **Travle** — aplikaciju za otkrivanje turističkih destinacija i rezervaciju tura, razvijenu u sklopu seminarskog rada iz predmeta Razvoj softvera II.

Sistem za preporuke jedna je od ključnih funkcionalnosti Travle platforme. Njegova svrha je da poveća angažman korisnika prikazujući destinacije koje odgovaraju individualnom ukusu i ponašanju svakog korisnika, umjesto generičke liste svih odobrenih destinacija. Sistem odgovara na jednostavno, ali važno pitanje svakog korisnika koji otvori mobilnu aplikaciju: _„Koju od svih dostupnih destinacija bih zaista trebao pogledati?“_

Sistem za preporuke implementiran je unutar ASP.NET Core Web API-ja kao **deterministički bodovni algoritam** zasnovan na filtriranju po sadržaju (_content-based filtering_): gradi se ponderisani profil korisnika, računa se **kosinusna sličnost** nad kategoričkim vektorima osobina, a rezultat se miješa sa mjerom popularnosti. Za korisnike bez dovoljno historije koristi se rezervni mehanizam čiste popularnosti (rješavanje problema cold starta). Preporuke se izračunavaju **na zahtjev** (bez treniranog modela i bez pozadinskog treniranja), izlažu kroz REST endpoint-e, a konzumira ih Flutter mobilna aplikacija koja ih prikazuje u sekciji „Recommended for you“ na početnom ekranu.

> **Napomena o jeziku:** Korisnički interfejs i tekstovi objašnjenja u samoj aplikaciji su na engleskom jeziku (npr. „Because you're interested in Nature“). U ovoj dokumentaciji ti se stringovi navode tačno onako kako ih kod generiše, uz objašnjenje na bosanskom jeziku, jer se ocjenjuje podudarnost dokumentacije i implementacije.

---

## 2. Ciljevi sistema za preporuke

Primarni ciljevi komponente za preporuke su:

- Svakom korisniku ponuditi kratku listu relevantnih destinacija prilagođenu njegovim interesima i historiji ponašanja.
- **Objasniti** zašto se svaka destinacija preporučuje (npr. „Because you're interested in Nature“) kako bi se izgradilo povjerenje korisnika u sistem.
- Riješiti **problem cold starta** za nove korisnike koji nemaju historiju interakcija.
- Osigurati da preporuke uvijek odražavaju **aktuelno** stanje podataka, bez rizika da izračunato stanje „zastari“.
- Raditi efikasno, sa vrlo malom latencijom, u okviru jednog zahtjeva prema API-ju.
- Održati **potpunu podudarnost dokumentacije i implementacije** — težine i formule opisane u ovom dokumentu identične su onima u kodu.

---

## 3. Arhitektura sistema

Cijeli sistem za preporuke izvršava se unutar `Travle.WebAPI` procesa. „Model“ je dokumentovana tabela težina i formula (vidi §4), verzionisana zajedno sa kodom — nema faze treniranja niti modela u memoriji. Sistem se sastoji od sljedećih komponenti:

### 3.1. RecommendationService

Glavni servis koji orkestrira izračun preporuka na zahtjev: učitava korisnikove interakcije i keširani katalog destinacija, gradi profil, poziva bodovni algoritam, sastavlja lagane DTO objekte (kartice sa thumbnailom), upisuje audit log i kešira rezultat. Registrovan je kao _scoped_ servis. Datoteka: `Travle.Services/RecommendationService.cs`.

### 3.2. RecommendationScorer

Čista, deterministička matematička jezgra (bez pristupa bazi i kešu): gradnja profila, kosinusna sličnost, mjera popularnosti, rangiranje, izbor najjačeg doprinosa za objašnjenje i item-to-item sličnost. Datoteka: `Travle.Services/Recommender/RecommendationScorer.cs`.

### 3.3. RecommendationCache

Wrapper oko `IMemoryCache` koji upravlja sa dva keš-unosa: (1) izračunata lista preporuka po korisniku (kratko trajanje, poništava se pri jakim interakcijama) i (2) zajednički katalog odobrenih destinacija (podaci koji se rijetko mijenjaju). Datoteke: `Travle.Services/Recommender/IRecommendationCache.cs`, `RecommendationCache.cs`.

### 3.4. RecommenderOptions („model“)

Jedno, centralno mjesto za sve podesive brojeve — tabelu težina signala i konstante formule. Zadane vrijednosti odgovaraju ovoj dokumentaciji, pa se svaka izmjena mora mijenjati istovremeno u kodu i u dokumentaciji. Datoteka: `Travle.Services/Recommender/RecommenderOptions.cs`.

### 3.5. Endpoint-i (kontroleri)

- `GET /Recommendations` — vraća personalizovane preporuke za prijavljenog korisnika (`RecommendationsController`).
- `GET /Destinations/{id}/similar` — vraća slične destinacije za jednu destinaciju (dodano u `DestinationsController`).

### 3.6. Perzistencija

- **Ulaz:** tabela `UserInteractions` (zabilježeni signali) — jedini perzistirani ulaz u bodovanje.
- **Izlaz:** tabela `RecommendationLogs` — audit log svake **prikazane** preporuke; nikad se ne koristi kao ulaz u bodovanje.

---

## 4. Opis algoritma

### 4.1. Izbor algoritma

Travle koristi **filtriranje zasnovano na sadržaju** (_content-based filtering_): iz korisnikovih interakcija gradi se ponderisani profil ukusa, koji se **kosinusnom sličnošću** poredi sa svakom kandidat-destinacijom, a rezultat se miješa sa mjerom popularnosti; korisnici bez dovoljno signala dobijaju listu po popularnosti (cold start). Algoritam je **deterministički** — „model“ je tabela težina i formula (§4.2–§4.6), bez faze treniranja i bez modela u memoriji.

Ovaj izbor direktno implementira temu odobrenog prijedloga — **ponderisane interakcije** („završena rezervacija je jači signal od pregleda“) — i po prirodi je **samoobjašnjiv**: osobina koja najviše doprinosi rezultatu ujedno je i razlog preporuke (§6). ML.NET u svom katalogu za preporuke nudi samo kolaborativno filtriranje (`MatrixFactorizationTrainer`), koje nema mjesto za ponderisane signale i ne objašnjava se samo, pa je na skali Travle platforme content-based pristup prirodniji izbor.

### 4.2. Signali i težine

Svaka relevantna radnja korisnika zapisuje se kao **interakcija** u tabelu `UserInteractions`, sa težinom koja predstavlja jačinu tog signala kao dokaza o ukusu. Sve interakcije se zapisuju na serverskoj strani — **klijent nikada ne šalje interakcije**.

| Radnja korisnika                | Tip interakcije (`InteractionType`) | Težina |
| ------------------------------- | ----------------------------------- | :----: |
| Završena rezervacija            | `BookingCompleted`                  |   5    |
| Plaćena/potvrđena rezervacija   | `BookingConfirmed`                  |   4    |
| Dodavanje u favorite            | `Favorite`                          |   3    |
| Recenzija ocjene 4–5            | `ReviewHigh`                        |   3    |
| Odabir interesa pri onboardingu | `OnboardingInterest`                |   2    |
| Pregled detalja destinacije     | `View`                              |   1    |
| Pretraga po kategoriji/tagu     | `Search`                            |   1    |

**Mjesta zapisivanja (u kodu):** endpoint za detalje (`View` + uvećanje `ViewCount`), endpoint za pretragu (`Search` + poklopljena kategorija/tag), servis favorita (`Favorite`), state machine rezervacije (`BookingConfirmed`/`BookingCompleted`), servis recenzija (`ReviewHigh`) i endpoint onboardinga (`OnboardingInterest`).

**Napomena o težinama:** bitan je **redoslijed i omjer** težina, a ne apsolutne vrijednosti. Kako se profil normalizuje (§4.4), množenje svih težina istom konstantom ne mijenja rezultat — vrijednosti `5/4/3/3/2/1/1` i `50/40/30/30/20/10/10` daju identične preporuke.

**Napomena o životnom vijeku signala:** tabela `UserInteractions` je **append-only** za sve signale osim jednog izuzetka — `ReviewHigh`. Pošto recenzija ocjene 4–5 kasnije može biti izmijenjena ispod praga ili uklonjena, njen prateći `ReviewHigh` red se usklađuje sa trenutnim stanjem recenzije (dodaje se kada ocjena uđe u opseg 4–5, briše kada padne ispod praga ili se recenzija ukloni), jer definišući uslov tog signala („ocjena 4–5“) tada više ne vrijedi. Uklanjanje favorita **ne** briše `Favorite` interakciju (append-only log), a vremensko slabljenje iz §4.4 prirodno umanjuje uticaj starih signala.

### 4.3. Prostor osobina (feature space)

Prostor osobina ima po jednu dimenziju za svaku **kategoriju destinacije** (`DestinationCategory`), svaki **tag** (`Tag`) i svaku **regiju** (`Region`). Svaka destinacija „označava“ nekoliko tih dimenzija (svoju jednu kategoriju, svoju jednu regiju i svoje tagove), pa je njen vektor **binaran** (0/1) i rijedak. Regija se dobiva preko lanca `Destination → City → Region`.

### 4.4. Profil korisnika

Profil korisnika je vektor nad istim prostorom osobina, ali sa realnim vrijednostima („pojačala“) umjesto 0/1. Gradi se u tri koraka:

1. **Agregacija težina po osobini.** Za svaku korisnikovu interakciju dodaje se njena težina na odgovarajuće dimenzije:
   - interakcija vezana za destinaciju (`View`, `Favorite`, `BookingConfirmed`, `BookingCompleted`, `ReviewHigh`) se **širi** na kategoriju, regiju i sve tagove te destinacije;
   - `OnboardingInterest` i `Search` doprinose direktno svojoj kategoriji ili tagu (bez destinacije).
2. **Vremensko pojačanje (recency).** Interakcije iz **posljednjih 30 dana** množe se faktorom **1.5** prije sumiranja. Ovo je mehanizam „zaboravljanja“: stariji interesi vremenom relativno slabe bez brisanja podataka.
3. **Normalizacija.** Vektor se skalira na **jediničnu dužinu** (dijeljenjem svake vrijednosti korijenom sume kvadrata). Time se zadržava samo _oblik_ ukusa (omjeri između osobina), a ne razina aktivnosti korisnika.

### 4.5. Kandidati

Kandidati su **sve odobrene** (`Approved`) destinacije za koje korisnik **nema završenu rezervaciju** (`BookingCompleted`). Destinacije koje je korisnik samo dodao u favorite **ostaju** kandidati (spašena-a-zaboravljena destinacija treba ponovo isplivati).

### 4.6. Bodovanje i rangiranje

Za svakog kandidata računaju se dvije komponente i njihova ponderisana kombinacija.

**Sadržajni rezultat (kosinusna sličnost):**

```
contentScore = kosinus(profil, vektor_destinacije)
```

Kosinusna sličnost mjeri koliko su „usmjereni u istom pravcu“ profil korisnika i binarni vektor destinacije, neovisno o njihovoj dužini (vrijednost 1 = savršeno poklapanje pravca, 0 = nema zajedničke osobine). Pošto je profil već jediničan, a vektor destinacije binaran, izraz se svodi na sumu profilskih vrijednosti za osobine koje destinacija posjeduje, podijeljenu korijenom broja tih osobina.

**Rezultat popularnosti:**

```
popularityScore = 0.7 · (AverageRating / 5)
                + 0.3 · ( log(1 + ViewCount) / log(1 + maxViewCount) )
```

Ocjena (`AverageRating`) nosi veći udio (0.7), a broj pregleda (`ViewCount`) manji (0.3), pri čemu se logaritmom postiže opadajući povrat popularnosti; `maxViewCount` je najveći broj pregleda u katalogu (kada nijedna destinacija nema preglede, taj sabirak je 0 — nema dijeljenja nulom).

**Konačni rezultat i rangiranje:**

```
finalScore = 0.8 · contentScore + 0.2 · popularityScore
```

Sadržaj nosi 4× veći udio od popularnosti (0.8 naspram 0.2) — sistem je prvenstveno personalizovan. Kandidati se sortiraju silazno po `finalScore`, a vraća se **najboljih 10**.

**Minimalni prag (threshold).** Kandidat mora imati `contentScore > 0`, tj. dijeliti **bar jednu osobinu** sa profilom korisnika — destinacija bez ijedne zajedničke osobine ne može dobiti objašnjenje pa se ne prikazuje u ovoj listi (i dalje je dostupna kroz zasebnu „Popular“ sekciju).

### 4.7. Objašnjenja (izvedena iz najjačeg doprinosa)

Objašnjenje se izvodi iz **osobine sa najvećim doprinosom** kosinusnom rezultatu za tu destinaciju (najviše „pojačana“ dimenzija koju destinacija dijeli sa profilom). Vidi §6 za tabelu tekstova.

### 4.8. Druga površina: slične destinacije

Na ekranu detalja destinacije prikazuje se traka **„Similar destinations“**. To je drugačije pitanje od personalizovane liste: umjesto _„šta odgovara tebi?“_, odgovara na _„šta je slično ovoj destinaciji?“_. Računa se **item-to-item kosinusna sličnost** između binarnog vektora posmatrane destinacije i vektora ostalih odobrenih destinacija — **bez profila korisnika**, pa radi i za potpuno nove korisnike. Vraća se **najboljih 5** sa pozitivnim preklapanjem. Objašnjenje se gradi iz zajedničkih osobina (npr. „Also in Herzegovina-Neretva“, „Shares the Ottoman theme“).

---

## 5. Problem cold starta

Cold start nastaje kada novi korisnik nema (dovoljno) historije, pa nema smislenog profila ukusa. Pravilo je:

> Ako je **ukupna ponderisana suma signala korisnika manja od 3**, preskače se personalizovano bodovanje i lista se rangira **isključivo po popularnosti** (§4.6), a odgovor se označava sa `isColdStart: true` kako bi ga aplikacija naslovila „Popular to get you started“.

Prag 3 je usklađen sa težinama: jedan onboarding odabir vrijedi 2 (i dalje cold start), dva odabira daju 4 (dovoljno za personalizaciju), a već jedan favorit / recenzija / rezervacija (težina 3+) prelazi prag. Čim postoji stvaran signal ukusa, prelazi se na personalizaciju; do tada je popularnost zadana lista. (Ova provjera koristi osnovne težine, bez vremenskog pojačanja.)

---

## 6. Objašnjive preporuke

Svaka vraćena preporuka nosi kratko, čitljivo objašnjenje. To je eksplicitan zahtjev projekta. Tekst se generiše na serverskoj strani na osnovu najjačeg signala za taj par (korisnik, destinacija):

| Signal (najjači doprinos) | Prikazani tekst (kako ga kod generiše)                |
| ------------------------- | ----------------------------------------------------- |
| Kategorija poklapa profil | `Because you're interested in {kategorija}`           |
| Tag poklapa profil        | `Shares a tag you like: {tag}`                        |
| Regija poklapa profil     | `In {regija}, a region you explore`                   |
| Popularnost / cold start  | `Popular right now — highly rated by other travelers` |

Za slične destinacije (§4.8) objašnjenje se gradi iz zajedničkih osobina: `Also a {kategorija} in {regija}`, `Also a {kategorija}`, `Also in {regija}` ili `Shares the {tag} theme`.

---

## 7. Skladištenje i keširanje

Arhitektura perzistencije je minimalna:

- **Ulaz:** samo `UserInteractions` — jedini izvor koji bodovanje čita.
- **Izračun na zahtjev:** pri `GET /Recommendations` servis učita korisnikove interakcije i katalog odobrenih destinacija (**keširan** u `IMemoryCache`), izgradi profil, boduje i sortira. Time preporuke uvijek odražavaju aktuelno stanje interakcija.
- **Izlaz:** svaka **prikazana** preporuka dopisuje se u `RecommendationLogs` (`UserId`, `DestinationId`, `Score`, `Reason`, `ServedAt`) — audit log, nikad ulaz u bodovanje.

**Keširanje.** Izračunata lista po korisniku pamti se ~**15 minuta** i **poništava** čim korisnik uradi nešto što mijenja njegov ukus (rezervacija potvrđena/završena, favorit, recenzija, onboarding). Slabi signali (`View`, `Search`) ne poništavaju keš — pokriva ih istek od 15 minuta. Katalog odobrenih destinacija keširan je zasebno jer se rijetko mijenja. Upis u `RecommendationLogs` dešava se samo pri stvarnom izračunu (ne pri cache hit-u, niti za „slične destinacije“).

---

## 8. Detalji implementacije

### 8.1. Backend (.NET)

Jezgro sistema živi u projektu `Travle.Services`:

- `RecommendationService.cs` — orkestracija: učitavanje podataka, poziv bodovnog algoritma, sastavljanje kartica, upis loga i keširanje.
- `Recommender/RecommendationScorer.cs` — čista matematika (profil, kosinus, popularnost, sličnost).
- `Recommender/RecommendationModels.cs` — pomoćni tipovi (`FeatureKind`, `FeatureKey`, `DestinationFeature`, `InteractionSignal`, `ScoredDestination`, `SimilarScored`).
- `Recommender/RecommenderOptions.cs` — težine i konstante formule („model“).
- `Recommender/IRecommendationCache.cs`, `RecommendationCache.cs` — keširanje nad `IMemoryCache`.
- `IRecommendationService.cs` — javni ugovor servisa.

Endpoint-i su u `Travle.WebAPI/Controllers/RecommendationsController.cs` (`GET /Recommendations`) i u `DestinationsController.cs` (`GET /Destinations/{id}/similar`). Mjesta zapisivanja signala su u `DestinationService`, `FavoriteService`, `DestinationReviewService`, `UserService` i klasama state machine-a rezervacije (`BaseBookingState`, `PendingBookingState`, `ConfirmedBookingState`).

### 8.2. Korištene tabele baze

- **UserInteractions** — zabilježeni signali (ulaz u bodovanje).
- **Destinations** — kandidati; denormalizovana polja `AverageRating` i `ViewCount` (popularnost).
- **DestinationCategories, Tags, Regions** — prostor osobina i imena za objašnjenja.
- **Cities** — lanac `Destination → City → Region`.
- **DestinationTags** — veza više-na-više destinacija i tagova.
- **Bookings** — završene rezervacije (isključivanje kandidata).
- **Favorites** — oznaka `isFavorite` na karticama.
- **RecommendationLogs** — audit log prikazanih preporuka (izlaz).

### 8.3. Frontend (Flutter mobilna aplikacija)

U dijeljenom paketu `travle_core` dodani su modeli `RecommendationItem` i `RecommendationResponse`, servis `RecommendationProvider` (`GET /Recommendations`) i metoda `DestinationProvider.similar(id)` (`GET /Destinations/{id}/similar`). U aplikaciji `travle_mobile`, početni ekran prikazuje sekciju „Recommended for you“ (kartice sa objašnjenjem i oznakom cold starta), a ekran detalja destinacije traku „Similar destinations“. Kartica `RecommendationCard` (naslovni thumbnail + rating badge + chip objašnjenja) dijeli se između obje površine.

---

## 9. API ugovor

### 9.1. GET /Recommendations

Vraća personalizovane preporuke za prijavljenog korisnika. Korisnik se identifikuje iz JWT tokena; nema tijela zahtjeva. Za korisnike u cold startu vraća se lista po popularnosti sa `isColdStart: true`.

**Autentikacija:** obavezan Bearer JWT.

**Odgovor (200 OK):**

```json
{
  "items": [
    {
      "destination": {
        "id": 11,
        "name": "Baščaršija",
        "categoryName": "Old Town",
        "cityName": "Sarajevo",
        "regionName": "Sarajevo",
        "averageRating": 4.6,
        "isFavorite": false,
        "primaryThumbnail": "…(base64 thumbnail)…"
      },
      "score": 0.3512,
      "reason": "Shares a tag you like: Ottoman"
    }
  ],
  "isColdStart": false
}
```

Svaka prikazana stavka dopisuje se u `RecommendationLogs`.

### 9.2. GET /Destinations/{id}/similar

Vraća do 5 destinacija sličnih zadanoj (item-to-item, bez profila korisnika); radi i za nove korisnike. Ne upisuje `RecommendationLogs`.

**Autentikacija:** obavezan Bearer JWT.

**Odgovor (200 OK):**

```json
[
  {
    "destination": {
      "id": 8,
      "name": "Počitelj",
      "categoryName": "Old Town",
      "regionName": "Herzegovina-Neretva"
    },
    "score": 0.5071,
    "reason": "Also in Herzegovina-Neretva"
  }
]
```

### 9.3. POST /Users/onboarding-interests

Prima listu ID-jeva kategorija/tagova i zapisuje ih kao `OnboardingInterest` interakcije (jednom, preskočivo). Poziva se pri onboardingu; ne šalje pojedinačne interakcije — sve ostale interakcije se bilježe na serverskoj strani unutar postojećih endpoint-a.

---

## 10. Zaključak

Sistem za preporuke platforme Travle isporučuje personalizovane prijedloge destinacija kroz **deterministički algoritam zasnovan na sadržaju**: ponderisani profil korisnika i **kosinusnu sličnost** nad kategoričkim vektorima osobina, pomiješane sa mjerom popularnosti (`0.8 · sadržaj + 0.2 · popularnost`). Cold start se rješava uključivanjem onboarding interesa u profil i rezervnom listom po popularnosti kada je ukupni signal ispod praga, a svaka preporuka nosi čitljivo objašnjenje.

„Model“ je dokumentovana tabela težina i formula, verzionisana zajedno sa kodom; preporuke se računaju na zahtjev, uz `IMemoryCache` za keširanje i `RecommendationLogs` kao trag prikazanih preporuka. Rješenje ne zahtijeva vanjsku ML infrastrukturu i u potpunosti se poklapa sa ovom dokumentacijom.
