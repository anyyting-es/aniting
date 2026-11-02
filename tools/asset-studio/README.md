# Aniting · Asset Studio

Local web tool to curate `assets/data/custom_anime_assets.json` — the per-AniList-ID
poster / background / logo overrides the app serves without querying TMDB at runtime.

It is a single Node file with no dependencies plus a vanilla HTML/CSS/JS UI.
Everything runs on `127.0.0.1:3333`.

## Run

```bash
node tools/asset-studio/server.mjs
# or, from this folder
npm start
```

Open <http://127.0.0.1:3333>.

Options:

```bash
PORT=3344 node tools/asset-studio/server.mjs        # another port
TMDB_API_KEY=xxxx node tools/asset-studio/server.mjs # another TMDB key
```

The TMDB key can also be changed from the top bar (stored in `localStorage` only).
Without one, the server uses the same default key the Flutter app ships with
(`tmdb_preferences_provider.dart`).

## What it does

- **Catalog** — lists every AniList ID already present in
  `assets/data/custom_anime_assets.json`, with its current poster and how many of the
  three images are set. Titles are hydrated from AniList in one batched GraphQL call.
- **AniList search** — type in the top bar, pick a result.
- **TMDB images** — resolves the AniList ID against
  `assets/data/anilist_tmdb_map.json` (AniList → TMDB/TVDB) and immediately loads every
  poster, backdrop and logo from TMDB, filterable by language / textless.
  For TV shows, a season selector also pulls that season's posters (which is exactly
  the art that generic TMDB series data gets wrong).
- **One-click save** — clicking an image writes the full URL into the JSON for that
  AniList ID and saves the file. Removing an image, or clearing all three, updates or
  removes the entry. Manual URL editing is available under each slot.
- **No TMDB mapping?** Search TMDB from the panel or paste a TMDB ID manually.

## Endpoints

| Method | Path | Purpose |
|---|---|---|
| GET | `/` | UI |
| GET | `/api/assets` | Raw catalog map — **the exact shape the Flutter app probes** |
| GET | `/api/assets?download=1` | Download the JSON file |
| GET | `/api/catalog` | `{catalog, count, path}` for the studio UI |
| POST | `/api/assets` | `{id, poster?, background?, logo?}` → merge + write |
| DELETE | `/api/assets/:id` | Remove an entry |
| GET | `/api/anilist/search?q=` | AniList search proxy |
| GET | `/api/anilist/media/:id` | AniList media details |
| POST | `/api/anilist/batch` | `{ids: []}` → media list |
| GET | `/api/tmdb/resolve?anilistId=` | AniList → TMDB mapping from the local JSON |
| GET | `/api/tmdb/details?anilistId=` | TMDB details (+ seasons) |
| GET | `/api/tmdb/images?anilistId=&season=` | Posters / backdrops / logos |
| GET | `/api/tmdb/search?q=&type=` | Manual TMDB search fallback |
| GET | `/api/health` | Sanity check + paths |

`X-Tmdb-Key` header overrides the TMDB key per request.

## How the Flutter app picks the changes up

- The desktop/dev build re-reads `assets/data/custom_anime_assets.json` from disk when
  its mtime changes (`CustomAnimeAssetsService._checkDiskUpdatesSync`), so saving here
  updates an already-running app.
- The app also probes `http://127.0.0.1:3333/api/assets` on startup
  (`CustomAnimeAssetsService._syncRemote`). This server serves that exact endpoint, so
  running the studio while opening the app syncs the catalog automatically.
- Bump/commit the JSON like any other asset change.

## Notes

- The server binds to `127.0.0.1` only and writes just
  `assets/data/custom_anime_assets.json`.
- Writes are serialised (quick consecutive picks can't lose an update).
- TMDB image URLs are stored as full `https://image.tmdb.org/t/p/original/...` links;
  the app's `CustomAnimeAssets.fromJson` accepts both full URLs and bare filenames, so
  existing relative entries keep working.
- AniList and TMDB are proxied server-side, so there are no CORS issues and the TMDB
  key never appears in image or metadata requests from the browser.
