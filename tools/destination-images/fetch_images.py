#!/usr/bin/env python3
"""
One-off developer tool: fetch one representative photo per seeded destination.

This is NOT part of the build or the runtime seed. It runs on a developer machine,
downloads the images once, and writes them into
`Backend/Travle.Services/Database/Seeding/DestinationImages/` where they are picked up
as embedded resources and seeded offline. `docker compose up` never touches the network.

    python fetch_images.py                 # fetch everything that is still missing
    python fetch_images.py --force         # re-fetch even if a file already exists
    python fetch_images.py --limit 10      # smoke test on the first 10
    python fetch_images.py --name "Stari Most"   # redo a single destination

Matching strategy, most trustworthy first (a loose full-text search alone picks the
wrong article roughly a third of the time, so every candidate is gated on title
similarity before its image is accepted):

  1. exact title match on bs/en Wikipedia
  2. geosearch around the destination's seeded coordinates  <- most reliable
  3. full-text search, accepted only if the title actually resembles the destination
  4. Commons file-namespace search, same gate

Output: <slug>.jpg, centre-cropped to the mobile gallery ratio and downscaled.
Every result is recorded in manifest.json with the page it came from and a confidence
level, so low-confidence picks can be reviewed and replaced individually.
"""

import argparse
import difflib
import json
import re
import sys
import threading
import time
import unicodedata
import urllib.error
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from io import BytesIO
from pathlib import Path

from PIL import Image, ImageOps

# --- output geometry -------------------------------------------------------
# The mobile details gallery is full-bleed width x 260dp with BoxFit.cover, i.e. a
# ratio of ~1.38 (360dp phone) to ~1.65 (430dp phone). 3:2 sits mid-band and is the
# native aspect of most source photos, so cropping costs almost nothing.
TARGET_W, TARGET_H = 1024, 683
JPEG_QUALITY = 80

# Ask Wikimedia for a pre-scaled rendition rather than the full original: a fraction
# of the bytes for identical output at our size, and far kinder to their servers.
REQUEST_THUMB_WIDTH = 1600
MIN_SOURCE_WIDTH = 640

# Coordinates in the seed are precise for landmarks but town-level for a few entries,
# so widen the net in stages and prefer the closest good title match.
GEO_RADII = (400, 1200)

# Name-based search can match an article about an entirely different continent
# ('Tunnel of Hope Museum' -> 'Hope Valley Line', a railway in England). Any candidate
# that carries coordinates must be in the right part of the world. Generous, because a
# river or national park is tagged at its centroid, not at our pin.
MAX_MATCH_DISTANCE_KM = 30.0
# A fuzzy search hit gets a much smaller budget than an exact title match.
MAX_SEARCH_DISTANCE_KM = 12.0

REPO_ROOT = Path(__file__).resolve().parents[2]
SEED_FILE = REPO_ROOT / "Backend/Travle.Services/Database/Seeding/SeedDestinations.cs"
OUT_DIR = REPO_ROOT / "Backend/Travle.Services/Database/Seeding/DestinationImages"
MANIFEST = Path(__file__).resolve().parent / "manifest.json"

USER_AGENT = "TravleSeedBot/1.0 (FIT student project; haris.velispahic@gmail.com)"

# Lead images that are clearly not a photo of the place. Wikipedia articles for towns
# and regions often lead with a coat of arms, flag or locator map; those are useless
# here, so treat them as a miss and let a human decide.
BAD_IMAGE_HINTS = (
    "coat of arms", "coatofarms", "wappen", "grb", "flag", "zastava", "civil ensign",
    "location", "locator", "map of", "karta", "mapa", "location_map",
    "blank", "logo", "seal of", "emblem", "orthographic", "globe",
)

# Words too common to prove two titles refer to the same place on their own.
STOPWORDS = {
    "the", "of", "and", "a", "an", "in", "at", "on", "na", "u", "i", "za", "od",
    "de", "la", "el", "new", "great", "little", "upper", "lower",
}

# Nouns naming a *kind* of place rather than a particular one, in English and in
# bs/hr/sr. Two titles sharing only one of these are not thereby the same place:
# 'Sacred Heart Cathedral' and 'Cathedral of the Nativity of the Theotokos' are
# different buildings 200m apart. Such an overlap must be corroborated by the
# whole-title similarity check before the match is accepted.
GENERIC_TYPE_TOKENS = {
    "cathedral", "katedrala", "church", "crkva", "chapel", "kapela",
    "mosque", "dzamija", "monastery", "manastir", "samostan", "tekija", "han",
    "fortress", "tvrdava", "castle", "dvorac", "kula", "tower", "palace", "palata",
    "bridge", "most", "museum", "muzej", "gallery", "galerija",
    "waterfall", "waterfalls", "vodopad", "slap", "slapovi",
    "lake", "jezero", "river", "rijeka", "reka", "spring", "springs", "vrelo", "izvor",
    "canyon", "kanjon", "gorge", "klisura", "valley", "dolina",
    "cave", "pecina", "mountain", "planina", "peak", "vrh", "hill", "brdo",
    "park", "national", "nacionalni", "nature", "priroda", "reserve", "rezervat",
    "old", "stari", "stara", "town", "grad", "city", "village", "selo",
    "square", "trg", "street", "ulica", "gate", "kapija", "wall", "walls", "zidine",
    "spa", "banja", "memorial", "memorijal", "monument", "spomenik",
    "tunnel", "tunel", "fountain", "fontana", "cesma",
    "island", "otok", "ostrvo", "beach", "plaza", "trail", "staza", "walk",
    "viewpoint", "vidikovac", "hall", "dom", "centre", "center", "centar",
    "site", "complex", "kompleks", "necropolis", "nekropola", "fort", "friary",
}

_print_lock = threading.Lock()


def log(msg):
    with _print_lock:
        print(msg, flush=True)


def deaccent(text: str) -> str:
    decomposed = unicodedata.normalize("NFKD", text)
    ascii_only = "".join(c for c in decomposed if not unicodedata.combining(c))
    return (ascii_only.replace("Đ", "D").replace("đ", "d")
                      .replace("Ł", "L").replace("ł", "l"))


def slugify(name: str) -> str:
    """Deterministic, ASCII-only slug. MUST stay in sync with the C# seeder's Slugify."""
    slug = re.sub(r"[^a-z0-9]+", "-", deaccent(name).lower())
    return slug.strip("-")


def tokens(text: str) -> set:
    raw = re.split(r"[^a-z0-9]+", deaccent(text).lower())
    return {t for t in raw if t and t not in STOPWORDS}


def title_matches(destination_name: str, page_title: str, strict: bool = False,
                  city: str | None = None) -> bool:
    """Does `page_title` plausibly refer to the same place?

    Guards against full-text search returning an article that merely mentions the
    destination (the failure that produced 'Sarajevo City Hall' -> 'Jusuf Hadzifejzovic').

    `strict` demands two distinctive words in common instead of one. Used when the
    candidate article has no coordinates to sanity-check against, where a single
    shared word is thin evidence ('Tunnel of Hope Museum' -> 'Hope Valley Line').

    `city` names the town the destination is in; its words are discounted, because
    every article in Travnik says 'Travnik' and matching on that alone pairs
    'Travnik Old Fort' with 'Sarena Mosque Travnik' -- a different landmark entirely.
    """
    # Drop a trailing disambiguator: "Kravica (waterfall)", "Sacred Heart Cathedral, Sarajevo".
    stripped = re.sub(r"\s*\([^)]*\)", "", page_title)
    stripped = stripped.split(",")[0]

    left, right = tokens(destination_name), tokens(stripped) or tokens(page_title)
    if not left or not right:
        return False

    # Count shared *distinctive* words, allowing for singular/plural and case endings
    # ("Waterfalls" ~ "waterfall", "Kravice" ~ "Kravica"). Type nouns are excluded
    # here so they cannot carry a match on their own.
    def same_word(a, b):
        if a == b:
            return True
        if len(a) >= 4 and len(b) >= 4:
            return (a.startswith(b) or b.startswith(a)
                    or difflib.SequenceMatcher(None, a, b).ratio() >= 0.8)
        return False

    uninformative = GENERIC_TYPE_TOKENS | (tokens(city) if city else set())
    right_distinctive = right - uninformative
    shared = sum(1 for a in left - uninformative
                 if any(same_word(a, b) for b in right_distinctive))
    if shared >= (2 if strict else 1):
        return True

    # Too little distinctive overlap. Accept only if the titles are near-identical
    # overall -- which is how genuinely generic names still match ("Stari Most").
    whole = difflib.SequenceMatcher(
        None, deaccent(destination_name).lower(), deaccent(stripped).lower()
    ).ratio()
    return whole >= 0.6


def is_bare_city_article(page_title: str, dest) -> bool:
    """Is this the article about the *town*, rather than about the landmark?

    A destination named after its city ('Travnik Old Fort', 'Franciscan Monastery of
    Fojnica') matches the town's own article on the shared name, and the town article
    leads with a panorama rather than the landmark. Those are worth rejecting so the
    more specific strategies get their turn; the town photo is still available as a
    last-resort fallback.
    """
    stripped = re.sub(r"\s*\([^)]*\)", "", page_title).split(",")[0]
    page_tokens, city_tokens = tokens(stripped), tokens(dest["city"])
    if not page_tokens or not city_tokens or not page_tokens <= city_tokens:
        return False
    # Unless the destination essentially *is* the town, in which case it is the right article.
    return bool(tokens(dest["name"]) - GENERIC_TYPE_TOKENS - city_tokens)


def parse_destinations():
    """Pull (city, name, category, lat, lng) out of the C# seed catalogue."""
    text = SEED_FILE.read_text(encoding="utf-8")
    pattern = re.compile(
        r'^\s*new\(\s*"([^"]+)"\s*,\s*"([^"]+)"\s*,\s*"([^"]+)"\s*,'
        r'\s*\[[^\]]*\]\s*,\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)',
        re.MULTILINE,
    )
    rows = []
    for m in pattern.finditer(text):
        rows.append({
            "city": m.group(1),
            "name": m.group(2),
            "category": m.group(3),
            "lat": float(m.group(4)),
            "lng": float(m.group(5)),
            "slug": slugify(m.group(2)),
        })
    return rows


def api_get(host, params, retries=3):
    params = dict(params, format="json", formatversion=2)
    url = f"https://{host}/w/api.php?" + urllib.parse.urlencode(params)
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(req, timeout=30) as resp:
                return json.load(resp)
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError):
            if attempt == retries - 1:
                return None
            time.sleep(1.5 * (attempt + 1))
    return None


def looks_like_junk(url: str) -> bool:
    lowered = urllib.parse.unquote(url).lower()
    return any(hint in lowered for hint in BAD_IMAGE_HINTS)


def haversine_km(lat1, lng1, lat2, lng2):
    from math import asin, cos, radians, sin, sqrt
    dlat, dlng = radians(lat2 - lat1), radians(lng2 - lng1)
    a = (sin(dlat / 2) ** 2
         + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlng / 2) ** 2)
    return 2 * 6371.0 * asin(sqrt(a))


def in_the_right_place(image, dest, max_km=MAX_MATCH_DISTANCE_KM):
    """Reject a candidate whose article sits too far from the destination.

    The budget tightens as the name evidence weakens: an exact title match can be
    trusted across a wide area (a national park is tagged at its centroid), but a
    fuzzy search hit must be close by, or 'Franciscan Monastery of Fojnica' happily
    matches the Franciscan friary two valleys over.

    An article without coordinates cannot be judged, so it passes -- the title gate
    is the only defence in that case.
    """
    lat, lng = image.get("page_lat"), image.get("page_lng")
    if lat is None or lng is None:
        return True
    return haversine_km(lat, lng, dest["lat"], dest["lng"]) <= max_km


def images_for_titles(host, titles):
    """Lead image and coordinates for each of `titles`. Returns {title: image dict}."""
    if not titles:
        return {}
    data = api_get(host, {
        "action": "query", "titles": "|".join(titles[:20]),
        "prop": "pageimages|coordinates", "piprop": "original|thumbnail",
        "pithumbsize": REQUEST_THUMB_WIDTH, "colimit": 50,
    })
    if not data:
        return {}

    found = {}
    for page in data.get("query", {}).get("pages", []):
        original = page.get("original")
        thumb = page.get("thumbnail") or original
        if not original or not thumb:
            continue
        if looks_like_junk(original["source"]):
            continue
        if original.get("width", 0) < MIN_SOURCE_WIDTH:
            continue
        coords = (page.get("coordinates") or [{}])[0]
        found[page.get("title", "")] = {
            "page_title": page.get("title", ""),
            "page_host": host,
            "download_url": thumb["source"],
            "source_url": original["source"],
            "source_width": original.get("width", 0),
            "source_height": original.get("height", 0),
            "page_lat": coords.get("lat"),
            "page_lng": coords.get("lon"),
        }
    return found


def try_exact_title(host, query, dest):
    """Strategy 1: the article literally called this."""
    data = api_get(host, {
        "action": "query", "list": "search", "srsearch": query,
        "srwhat": "nearmatch", "srlimit": 1,
    })
    if not data:
        return None
    hits = data.get("query", {}).get("search", [])
    if not hits:
        return None
    title = hits[0]["title"]
    if not title_matches(dest["name"], title, city=dest["city"]) \
            or is_bare_city_article(title, dest):
        return None
    image = images_for_titles(host, [title]).get(title)
    if not image or not in_the_right_place(image, dest):
        return None
    image["confidence"] = "high"
    image["matched_by"] = f"exact title on {host}"
    return image


_geo_cache = {}
_geo_lock = threading.Lock()


def geo_nearby(host, dest, radius):
    """Articles within `radius` metres of the destination, with their lead images."""
    key = (host, dest["lat"], dest["lng"], radius)
    with _geo_lock:
        if key in _geo_cache:
            return _geo_cache[key]

    data = api_get(host, {
        "action": "query", "list": "geosearch",
        "gscoord": f"{dest['lat']}|{dest['lng']}",
        "gsradius": radius, "gslimit": 20,
    })
    nearby = (data or {}).get("query", {}).get("geosearch", [])
    images = images_for_titles(host, [p["title"] for p in nearby]) if nearby else {}
    result = (nearby, images)

    with _geo_lock:
        _geo_cache[key] = result
    return result


def try_geosearch_titled(host, dest):
    """Strategy 2: an article at these coordinates whose title also matches. Best signal
    there is -- the right place, confirmed twice."""
    for radius in GEO_RADII:
        nearby, images = geo_nearby(host, dest, radius)
        named = [p for p in nearby
                 if title_matches(dest["name"], p["title"], city=dest["city"])
                 and not is_bare_city_article(p["title"], dest)]
        for page in sorted(named, key=lambda p: p.get("dist", 0)):
            image = images.get(page["title"])
            if image:
                image["confidence"] = "high"
                image["matched_by"] = f"geosearch {int(page.get('dist', 0))}m + title on {host}"
                return image
    return None


def try_geosearch_nearest(host, dest):
    """Last resort: the closest article with a photo, name notwithstanding.

    In a dense old town this happily returns the building next door (the mosque 53m
    from the Sebilj), so it runs only after every name-validated strategy has failed
    and its results are flagged 'low' for review.
    """
    nearby, images = geo_nearby(host, dest, GEO_RADII[0])
    for page in sorted(nearby, key=lambda p: p.get("dist", 0)):
        if page.get("dist", 1e9) > 250:
            break
        image = images.get(page["title"])
        if image:
            image["confidence"] = "low"
            image["matched_by"] = f"nearest article {int(page.get('dist', 0))}m on {host}"
            return image
    return None


def try_fulltext(host, query, dest):
    """Strategy 3: ordinary search, gated on both the title and the geography."""
    data = api_get(host, {
        "action": "query", "list": "search", "srsearch": query, "srlimit": 5,
    })
    if not data:
        return None
    for hit in data.get("query", {}).get("search", []):
        title = hit["title"]
        if not title_matches(dest["name"], title, city=dest["city"]) \
                or is_bare_city_article(title, dest):
            continue
        image = images_for_titles(host, [title]).get(title)
        if not image:
            continue
        if image.get("page_lat") is None:
            # Nothing to check the geography against, so the name must carry more weight.
            if not title_matches(dest["name"], title, strict=True, city=dest["city"]):
                continue
        elif not in_the_right_place(image, dest, MAX_SEARCH_DISTANCE_KM):
            continue
        image["confidence"] = "medium"
        image["matched_by"] = f"search '{query}' on {host}"
        return image
    return None


def try_commons(query, dest):
    """Strategy 4: a file on Commons named after the place.

    Commons files carry no coordinates at all, so there is nothing to check the
    geography against except the filename itself -- and a real photo of the place
    almost always names the town. Requiring that is blunt (it loses a few correct
    files whose name omits the town, which then fall back to a town photo) but
    without it the name alone drags in a spring in Slovenia for 'Bistrica Springs',
    Victorian baths in England for 'Salt Museum & Turkish Baths', and the 'Boston
    Society of Water Color Painters' for 'Sixth Blue Water'.
    """
    data = api_get("commons.wikimedia.org", {
        "action": "query", "generator": "search", "gsrsearch": query,
        "gsrnamespace": 6, "gsrlimit": 8,
        "prop": "imageinfo", "iiprop": "url|size", "iiurlwidth": REQUEST_THUMB_WIDTH,
    })
    if not data:
        return None
    city_tokens = tokens(dest["city"])
    for page in data.get("query", {}).get("pages", []):
        title = page.get("title", "")
        filename = re.sub(r"^File:", "", title)
        stem = Path(filename).stem
        if not title_matches(dest["name"], stem, city=dest["city"]):
            continue
        if not city_tokens & tokens(stem):
            continue
        info = (page.get("imageinfo") or [{}])[0]
        if not info.get("url") or looks_like_junk(info["url"]):
            continue
        if info.get("width", 0) < MIN_SOURCE_WIDTH:
            continue
        return {
            "page_title": title,
            "page_host": "commons.wikimedia.org",
            "download_url": info.get("thumburl") or info["url"],
            "source_url": info["url"],
            "source_width": info.get("width", 0),
            "source_height": info.get("height", 0),
            "confidence": "medium",
            "matched_by": f"commons '{query}'",
        }
    return None


def try_city_article(host, dest):
    """Very last resort: a photo of the town the destination sits in.

    Not the landmark, but a real photograph of the right place, which beats a flat
    colour block. Always flagged 'low' so it is reviewed.
    """
    data = api_get(host, {
        "action": "query", "list": "search", "srsearch": dest["city"],
        "srwhat": "nearmatch", "srlimit": 1,
    })
    hits = (data or {}).get("query", {}).get("search", [])
    if not hits:
        return None
    title = hits[0]["title"]
    image = images_for_titles(host, [title]).get(title)
    if not image or not in_the_right_place(image, dest):
        return None
    image["confidence"] = "low"
    image["matched_by"] = f"town article '{title}' on {host} (no landmark photo)"
    return image


def locate(dest):
    name = dest["name"]
    # "Yellow Fortress (Žuta Tabija)" -> try both the English name and the local one,
    # since the article is usually filed under whichever is native.
    bare = re.sub(r"\s*\([^)]*\)", "", name).strip()
    aside = re.search(r"\(([^)]*)\)", name)
    variants = [bare] + ([aside.group(1).strip()] if aside else [])

    for host in ("bs.wikipedia.org", "en.wikipedia.org"):
        for query in variants:
            hit = try_exact_title(host, query, dest)
            if hit:
                return hit
            time.sleep(0.15)

    for host in ("bs.wikipedia.org", "en.wikipedia.org"):
        hit = try_geosearch_titled(host, dest)
        if hit:
            return hit
        time.sleep(0.15)

    for host in ("bs.wikipedia.org", "en.wikipedia.org"):
        for query in variants:
            hit = try_fulltext(host, f"{query} {dest['city']}", dest) or \
                  try_fulltext(host, query, dest)
            if hit:
                return hit
            time.sleep(0.15)

    for query in variants:
        hit = try_commons(f"{query} {dest['city']}", dest) or try_commons(query, dest)
        if hit:
            return hit

    # Everything name-based has failed; fall back to pure proximity, then to a photo of
    # the town itself. Both are flagged for review.
    for host in ("bs.wikipedia.org", "en.wikipedia.org"):
        hit = try_geosearch_nearest(host, dest)
        if hit:
            return hit

    for host in ("bs.wikipedia.org", "en.wikipedia.org"):
        hit = try_city_article(host, dest)
        if hit:
            return hit
    return None


def download(url):
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=60) as resp:
        return resp.read()


def crop_and_save(raw, out_path):
    """Centre-crop to the gallery ratio, downscale, save baseline JPEG."""
    image = Image.open(BytesIO(raw))
    image = ImageOps.exif_transpose(image)          # honour camera rotation
    if image.mode != "RGB":
        image = image.convert("RGB")

    target_ratio = TARGET_W / TARGET_H
    width, height = image.size
    if width / height > target_ratio:               # too wide -> trim sides
        new_width = round(height * target_ratio)
        left = (width - new_width) // 2
        image = image.crop((left, 0, left + new_width, height))
    else:                                           # too tall -> trim top/bottom
        new_height = round(width / target_ratio)
        # Bias slightly above centre: for buildings and landscapes the subject
        # sits above the midline more often than below it.
        top = int((height - new_height) * 0.4)
        image = image.crop((0, top, width, top + new_height))

    image = image.resize((TARGET_W, TARGET_H), Image.LANCZOS)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    image.save(out_path, "JPEG", quality=JPEG_QUALITY, optimize=True, progressive=False)
    return out_path.stat().st_size


def load_previous_manifest():
    """Earlier results, so a partial re-run does not lose the provenance of files it skips."""
    if not MANIFEST.exists():
        return {}
    try:
        return {entry["name"]: entry for entry in json.loads(MANIFEST.read_text(encoding="utf-8"))}
    except (json.JSONDecodeError, KeyError, TypeError):
        return {}


def process(dest, force, previous):
    out_path = OUT_DIR / f"{dest['slug']}.jpg"
    if out_path.exists() and not force:
        earlier = previous.get(dest["name"], {})
        carried = {k: v for k, v in earlier.items()
                   if k in ("page_title", "page_host", "source_url", "matched_by", "confidence")}
        return {**dest, **carried, "status": "skipped", "bytes": out_path.stat().st_size,
                "file": out_path.name}

    try:
        hit = locate(dest)
    except Exception as exc:
        return {**dest, "status": "error", "reason": f"lookup failed: {exc}"}

    if not hit:
        log(f"  MISS  {dest['name']}")
        return {**dest, "status": "miss", "reason": "no confident match"}

    try:
        raw = download(hit["download_url"])
        size = crop_and_save(raw, out_path)
    except Exception as exc:
        log(f"  ERROR {dest['name']}: {exc}")
        return {**dest, "status": "error", "reason": str(exc), **hit}

    flag = " " if hit["confidence"] == "high" else "?"
    log(f" {flag}ok   {dest['name']:<42.42s} <- {hit['page_title'][:38]:<38.38s} ({size // 1024} KB)")
    return {**dest, "status": "ok", "bytes": size, "file": out_path.name, **hit}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--force", action="store_true", help="re-fetch existing files")
    parser.add_argument("--limit", type=int, help="only process the first N destinations")
    parser.add_argument("--name", help="only process destinations whose name contains this")
    parser.add_argument("--workers", type=int, default=4)
    args = parser.parse_args()

    destinations = parse_destinations()
    if args.name:
        needle = args.name.lower()
        destinations = [d for d in destinations if needle in d["name"].lower()]
    if args.limit:
        destinations = destinations[:args.limit]

    if not destinations:
        print("No destinations matched.", file=sys.stderr)
        return 1

    # A slug collision would make two destinations fight over one file.
    seen = {}
    for d in destinations:
        seen.setdefault(d["slug"], []).append(d["name"])
    collisions = {s: n for s, n in seen.items() if len(n) > 1}
    if collisions:
        print("Slug collisions detected:", file=sys.stderr)
        for slug, names in collisions.items():
            print(f"  {slug}: {names}", file=sys.stderr)
        return 1

    print(f"{len(destinations)} destination(s) -> {OUT_DIR}")
    print(f"target {TARGET_W}x{TARGET_H} JPEG q{JPEG_QUALITY}  ('?' = needs a look)\n")

    previous = load_previous_manifest()
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        results = list(pool.map(lambda d: process(d, args.force, previous), destinations))

    # Classify every destination that ended up with a file, whether fetched now or
    # carried over from a previous run, so the review lists are always complete.
    have = [r for r in results if r["status"] in ("ok", "skipped")]
    high = [r for r in have if r.get("confidence") == "high"]
    medium = [r for r in have if r.get("confidence") == "medium"]
    low = [r for r in have if r.get("confidence") == "low"]
    skipped = [r for r in results if r["status"] == "skipped"]
    misses = [r for r in results if r["status"] in ("miss", "error")]

    MANIFEST.write_text(
        json.dumps(sorted(results, key=lambda r: r["name"]), indent=2, ensure_ascii=False),
        encoding="utf-8",
    )

    total = sum(r.get("bytes", 0) for r in results if r["status"] in ("ok", "skipped"))
    print(f"\nconfident {len(high)} | name-matched {len(medium)} | proximity-only {len(low)} | "
          f"no image {len(misses)} | already present {len(skipped)} | "
          f"total {total / 1048576:.1f} MB")

    if medium:
        print("\nName-matched by search (usually right, quick sanity check):")
        for r in sorted(medium, key=lambda r: r["name"]):
            print(f"  {r['name']:<44.44s} <- {r['page_title']:<40.40s} [{r['matched_by']}]")

    if low:
        print("\nProximity only -- REVIEW THESE, may be the building next door:")
        for r in sorted(low, key=lambda r: r["name"]):
            print(f"  {r['name']:<44.44s} <- {r['page_title']:<40.40s} [{r['matched_by']}]")

    if misses:
        print("\nNo image found:")
        for r in sorted(misses, key=lambda r: r["name"]):
            print(f"  {r['city']:<18.18s} {r['name']:<46.46s} {r.get('reason', '')}")

    print(f"\nmanifest -> {MANIFEST}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
