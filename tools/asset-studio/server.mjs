#!/usr/bin/env node
/**
 * Aniting Asset Studio
 * --------------------
 * Local companion server + web UI to curate `assets/data/custom_anime_assets.json`.
 *
 * - Serves the UI on http://127.0.0.1:3333
 * - GET  /api/assets                 -> the current custom assets JSON
 *                                        (also the endpoint the Flutter app
 *                                        already probes at 127.0.0.1:3333)
 * - POST /api/assets                 -> { id, background?, logo?, poster? }
 * - DELETE /api/assets/:id           -> removes an entry
 * - AniList / TMDB proxies (no CORS problems, key kept out of the page)
 *
 * Zero dependencies: needs Node 18+ (global fetch).
 */

import { createServer } from 'node:http';
import { readFile, writeFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..', '..');
const PUBLIC_DIR = path.join(__dirname, 'public');
const ASSETS_JSON = path.join(ROOT, 'assets', 'data', 'custom_anime_assets.json');
const ID_MAP_JSON = path.join(ROOT, 'assets', 'data', 'anilist_tmdb_map.json');

const HOST = process.env.HOST ?? '127.0.0.1';
const PORT = Number(process.env.PORT ?? process.argv[2] ?? 3333);

/// Same default the Flutter app ships with (`tmdb_preferences_provider.dart`).
/// Override it with TMDB_API_KEY or from the UI.
const DEFAULT_TMDB_KEY =
  process.env.TMDB_API_KEY ?? '11f51d424de962a06b01b8bec43d9afa';

const ANILIST_ENDPOINT = 'https://graphql.anilist.co';
const TMDB_ENDPOINT = 'https://api.themoviedb.org/3';
const TMDB_IMAGE_BASE = 'https://image.tmdb.org/t/p/original';
const IMAGE_LANGUAGES = [
  'null',
  'en',
  'es',
  'ja',
  'pt',
  'fr',
  'de',
  'it',
  'ko',
  'zh',
  'ru',
  'hi',
  'ar',
  'tl',
].join(',');

// ---------------------------------------------------------------------------
// Small helpers
// ---------------------------------------------------------------------------

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.ico': 'image/x-icon',
  '.woff2': 'font/woff2',
};

function sendJson(res, status, data) {
  const body = JSON.stringify(data);
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(body),
    'Cache-Control': 'no-store',
    // Harmless here, and handy if the page is opened from another origin.
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type, X-Tmdb-Key',
    'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
  });
  res.end(body);
}

function sendError(res, status, message) {
  sendJson(res, status, { error: String(message ?? 'Unknown error') });
}

async function readJsonBody(req, limitBytes = 1_000_000) {
  const chunks = [];
  let size = 0;
  for await (const chunk of req) {
    size += chunk.length;
    if (size > limitBytes) throw new Error('Request body too large');
    chunks.push(chunk);
  }
  if (chunks.length === 0) return {};
  return JSON.parse(Buffer.concat(chunks).toString('utf8'));
}

function sortNumericKeys(object) {
  const entries = Object.entries(object).sort((a, b) => {
    const na = Number(a[0]);
    const nb = Number(b[0]);
    if (Number.isFinite(na) && Number.isFinite(nb)) return na - nb;
    return String(a[0]).localeCompare(String(b[0]));
  });
  return Object.fromEntries(entries);
}

async function fetchJson(url, options = {}, timeoutMs = 20_000) {
  const response = await fetch(url, {
    ...options,
    signal: AbortSignal.timeout(timeoutMs),
  });
  const text = await response.text();
  let json = null;
  try {
    json = text ? JSON.parse(text) : null;
  } catch {
    json = null;
  }
  if (!response.ok) {
    const detail =
      json?.status_message ?? json?.errors?.[0]?.message ?? text?.slice(0, 300);
    throw new Error(`HTTP ${response.status}${detail ? `: ${detail}` : ''}`);
  }
  return json;
}

// ---------------------------------------------------------------------------
// Catalog (assets/data/custom_anime_assets.json)
// ---------------------------------------------------------------------------

async function readCatalog() {
  try {
    const raw = await readFile(ASSETS_JSON, 'utf8');
    const parsed = JSON.parse(raw);
    return parsed && typeof parsed === 'object' && !Array.isArray(parsed)
      ? parsed
      : {};
  } catch (error) {
    if (error.code === 'ENOENT') return {};
    throw error;
  }
}

// Serialise writes: two quick picks must never interleave and lose an update.
let writeQueue = Promise.resolve();
function enqueueWrite(catalog) {
  writeQueue = writeQueue.then(async () => {
    const sorted = sortNumericKeys(catalog);
    await writeFile(ASSETS_JSON, `${JSON.stringify(sorted, null, 2)}\n`, 'utf8');
    return sorted;
  });
  return writeQueue;
}

// ---------------------------------------------------------------------------
// AniList
// ---------------------------------------------------------------------------

const ANILIST_MEDIA_FIELDS = `
  id
  idMal
  title { romaji english native }
  format
  status
  seasonYear
  episodes
  duration
  genres
  isAdult
  siteUrl
  coverImage { extraLarge large color }
  bannerImage
`;

async function anilistRequest(query, variables) {
  const json = await fetchJson(ANILIST_ENDPOINT, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Accept: 'application/json',
    },
    body: JSON.stringify({ query, variables }),
  });
  if (json?.errors?.length) {
    throw new Error(json.errors[0]?.message ?? 'AniList error');
  }
  return json?.data ?? {};
}

async function anilistSearch(query, page = 1) {
  const data = await anilistRequest(
    `query ($q: String, $page: Int) {
      Page(page: $page, perPage: 24) {
        media(search: $q, type: ANIME, isAdult: false, sort: SEARCH_MATCH) {
          ${ANILIST_MEDIA_FIELDS}
        }
      }
    }`,
    { q: query, page },
  );
  return data.Page?.media ?? [];
}

async function anilistMedia(id) {
  const data = await anilistRequest(
    `query ($id: Int) { Media(id: $id, type: ANIME) { ${ANILIST_MEDIA_FIELDS} } }`,
    { id },
  );
  return data.Media ?? null;
}

async function anilistBatch(ids) {
  const unique = [...new Set(ids.map(Number).filter((n) => n > 0))];
  const result = [];
  for (let i = 0; i < unique.length; i += 50) {
    const chunk = unique.slice(i, i + 50);
    const data = await anilistRequest(
      `query ($ids: [Int]) {
        Page(page: 1, perPage: 50) {
          media(id_in: $ids, type: ANIME) {
            id
            title { romaji english native }
            format
            seasonYear
            episodes
            coverImage { large }
            isAdult
          }
        }
      }`,
      { ids: chunk },
    );
    result.push(...(data.Page?.media ?? []));
  }
  return result;
}

// ---------------------------------------------------------------------------
// AniList -> TMDB/TVDB cross-reference (assets/data/anilist_tmdb_map.json)
// ---------------------------------------------------------------------------

let idMapCache = null;

async function getIdMap() {
  if (idMapCache) return idMapCache;
  const map = new Map();
  try {
    const raw = await readFile(ID_MAP_JSON, 'utf8');
    const parsed = JSON.parse(raw);
    for (const [key, value] of Object.entries(parsed)) {
      const anilistId = Number(key);
      if (!Number.isFinite(anilistId) || !Array.isArray(value)) continue;
      map.set(anilistId, {
        tmdbId: Number(value[0]) || 0,
        isMovie: Number(value[1]) === 1,
        tvdbId: Number(value[2]) || 0,
      });
    }
  } catch (error) {
    console.warn('[asset-studio] Could not read anilist_tmdb_map.json:', error.message);
  }
  idMapCache = map;
  return map;
}

// ---------------------------------------------------------------------------
// TMDB
// ---------------------------------------------------------------------------

function tmdbKey(req, url) {
  return (
    req.headers['x-tmdb-key'] ||
    url.searchParams.get('key') ||
    DEFAULT_TMDB_KEY
  );
}

async function tmdbGet(req, url, pathname, params = {}) {
  const search = new URLSearchParams(params);
  search.set('api_key', tmdbKey(req, url));
  const target = `${TMDB_ENDPOINT}${pathname}?${search.toString()}`;
  return fetchJson(target);
}

function normalizeImages(payload, kind) {
  const list = Array.isArray(payload?.[kind]) ? payload[kind] : [];
  return list
    .filter((image) => image && typeof image.file_path === 'string')
    .map((image) => ({
      filePath: image.file_path,
      url: `${TMDB_IMAGE_BASE}${image.file_path}`,
      language: image.iso_639_1 ?? null,
      width: image.width ?? null,
      height: image.height ?? null,
      aspectRatio: image.aspect_ratio ?? null,
      voteAverage: image.vote_average ?? 0,
      voteCount: image.vote_count ?? 0,
    }))
    .sort(
      (a, b) =>
        b.voteAverage - a.voteAverage ||
        b.voteCount - a.voteCount ||
        (b.width ?? 0) - (a.width ?? 0),
    );
}

async function tmdbDetails(req, url, { tmdbId, type, language = 'es-ES' }) {
  const pathname = type === 'movie' ? `/movie/${tmdbId}` : `/tv/${tmdbId}`;
  const data = await tmdbGet(req, url, pathname, { language });
  const seasons = Array.isArray(data.seasons)
    ? data.seasons
        .filter((season) => Number.isFinite(season.season_number))
        .map((season) => ({
          number: season.season_number,
          name: season.name,
          episodeCount: season.episode_count ?? null,
          airDate: season.air_date ?? null,
          posterUrl: season.poster_path
            ? `${TMDB_IMAGE_BASE}${season.poster_path}`
            : null,
        }))
    : [];
  return {
    tmdbId,
    type,
    name: data.name ?? data.title ?? null,
    originalName: data.original_name ?? data.original_title ?? null,
    year: Number(
      (data.first_air_date ?? data.release_date ?? '').slice(0, 4),
    ) || null,
    overview: data.overview ?? null,
    posterUrl: data.poster_path ? `${TMDB_IMAGE_BASE}${data.poster_path}` : null,
    backdropUrl: data.backdrop_path
      ? `${TMDB_IMAGE_BASE}${data.backdrop_path}`
      : null,
    seasons,
  };
}

async function resolveTmdbTarget(req, url) {
  const explicitType = url.searchParams.get('type');
  const explicitId = Number(url.searchParams.get('id'));
  if (explicitType && explicitId > 0) {
    return { tmdbId: explicitId, type: explicitType === 'movie' ? 'movie' : 'tv' };
  }

  const anilistId = Number(url.searchParams.get('anilistId'));
  if (!Number.isFinite(anilistId) || anilistId <= 0) {
    throw new Error('Missing anilistId (or type+id) parameter');
  }

  const map = await getIdMap();
  const mapping = map.get(anilistId);
  if (mapping && mapping.tmdbId > 0) {
    return {
      tmdbId: mapping.tmdbId,
      type: mapping.isMovie ? 'movie' : 'tv',
      tvdbId: mapping.tvdbId || null,
      source: 'map',
    };
  }

  return {
    tmdbId: 0,
    type: null,
    tvdbId: mapping?.tvdbId || null,
    source: 'none',
  };
}

// ---------------------------------------------------------------------------
// Static files
// ---------------------------------------------------------------------------

async function serveStatic(req, res, url) {
  let pathname = decodeURIComponent(url.pathname);
  if (pathname === '/' || pathname === '') pathname = '/index.html';

  const relative = path.normalize(pathname).replace(/^([/\\])+/, '');
  const target = path.join(PUBLIC_DIR, relative);
  if (!target.startsWith(PUBLIC_DIR)) {
    sendError(res, 403, 'Forbidden');
    return;
  }
  if (!existsSync(target)) {
    sendError(res, 404, 'Not found');
    return;
  }

  const body = await readFile(target);
  res.writeHead(200, {
    'Content-Type': MIME[path.extname(target).toLowerCase()] ?? 'application/octet-stream',
    'Content-Length': body.length,
    'Cache-Control': 'no-store',
  });
  res.end(body);
}

// ---------------------------------------------------------------------------
// Router
// ---------------------------------------------------------------------------

const server = createServer(async (req, res) => {
  const url = new URL(req.url ?? '/', `http://${HOST}:${PORT}`);

  if (req.method === 'OPTIONS') {
    sendJson(res, 204, {});
    return;
  }

  try {
    // ---- Catalog -------------------------------------------------------
    // `/api/assets` keeps the exact shape the Flutter app already probes at
    // http://127.0.0.1:3333/api/assets: a plain map of AniList ID -> assets.
    if (url.pathname === '/api/assets' && req.method === 'GET') {
      const catalog = sortNumericKeys(await readCatalog());
      const body = `${JSON.stringify(catalog, null, 2)}\n`;
      res.writeHead(200, {
        'Content-Type': 'application/json; charset=utf-8',
        'Content-Length': Buffer.byteLength(body),
        'Cache-Control': 'no-store',
        'Access-Control-Allow-Origin': '*',
        ...(url.searchParams.get('download') === '1'
          ? { 'Content-Disposition': 'attachment; filename="custom_anime_assets.json"' }
          : {}),
      });
      res.end(body);
      return;
    }

    // Envelope for the studio UI (count + path alongside the catalog).
    if (url.pathname === '/api/catalog' && req.method === 'GET') {
      const catalog = await readCatalog();
      sendJson(res, 200, {
        count: Object.keys(catalog).length,
        catalog,
        path: path.relative(ROOT, ASSETS_JSON),
      });
      return;
    }

    if (url.pathname === '/api/assets' && req.method === 'POST') {
      const body = await readJsonBody(req);
      const id = Number(body.id ?? body.anilistId);
      if (!Number.isFinite(id) || id <= 0) {
        sendError(res, 400, 'A positive numeric `id` (AniList ID) is required');
        return;
      }

      const catalog = await readCatalog();
      const entry = { ...(catalog[id] ?? {}) };
      for (const slot of ['background', 'logo', 'poster']) {
        if (!(slot in body)) continue;
        const value = body[slot];
        if (value == null || String(value).trim() === '') {
          delete entry[slot];
        } else {
          entry[slot] = String(value).trim();
        }
      }

      if (Object.keys(entry).length === 0) delete catalog[id];
      else catalog[id] = entry;

      const saved = await enqueueWrite(catalog);
      sendJson(res, 200, {
        ok: true,
        id,
        entry: saved[id] ?? null,
        count: Object.keys(saved).length,
        catalog: saved,
        path: path.relative(ROOT, ASSETS_JSON),
      });
      return;
    }

    if (url.pathname.startsWith('/api/assets/') && req.method === 'DELETE') {
      const id = Number(url.pathname.slice('/api/assets/'.length));
      if (!Number.isFinite(id) || id <= 0) {
        sendError(res, 400, 'Invalid id');
        return;
      }
      const catalog = await readCatalog();
      delete catalog[id];
      const saved = await enqueueWrite(catalog);
      sendJson(res, 200, {
        ok: true,
        id,
        count: Object.keys(saved).length,
        catalog: saved,
      });
      return;
    }

    // ---- AniList -------------------------------------------------------
    if (url.pathname === '/api/anilist/search') {
      const query = (url.searchParams.get('q') ?? '').trim();
      const page = Number(url.searchParams.get('page') ?? 1) || 1;
      if (query.length < 2) {
        sendJson(res, 200, { results: [] });
        return;
      }
      const results = await anilistSearch(query, page);
      sendJson(res, 200, { results });
      return;
    }

    if (url.pathname.startsWith('/api/anilist/media/')) {
      const id = Number(url.pathname.slice('/api/anilist/media/'.length));
      if (!Number.isFinite(id) || id <= 0) {
        sendError(res, 400, 'Invalid AniList id');
        return;
      }
      const media = await anilistMedia(id);
      sendJson(res, 200, { media });
      return;
    }

    if (url.pathname === '/api/anilist/batch' && req.method === 'POST') {
      const body = await readJsonBody(req);
      const ids = Array.isArray(body.ids) ? body.ids : [];
      const media = await anilistBatch(ids);
      sendJson(res, 200, { media });
      return;
    }

    // ---- TMDB ----------------------------------------------------------
    if (url.pathname === '/api/tmdb/resolve') {
      const target = await resolveTmdbTarget(req, url);
      sendJson(res, 200, target);
      return;
    }

    if (url.pathname === '/api/tmdb/details') {
      const target = await resolveTmdbTarget(req, url);
      if (!target.tmdbId) {
        sendJson(res, 200, { ...target, details: null });
        return;
      }
      const details = await tmdbDetails(req, url, target);
      sendJson(res, 200, { ...target, details });
      return;
    }

    if (url.pathname === '/api/tmdb/images') {
      const target = await resolveTmdbTarget(req, url);
      if (!target.tmdbId) {
        sendJson(res, 200, {
          ...target,
          posters: [],
          backdrops: [],
          logos: [],
          seasonPosters: [],
        });
        return;
      }

      const [seriesPayload, details] = await Promise.all([
        tmdbGet(
          req,
          url,
          `/${target.type}/${target.tmdbId}/images`,
          { include_image_language: IMAGE_LANGUAGES },
        ),
        tmdbDetails(req, url, target).catch(() => null),
      ]);

      const posters = normalizeImages(seriesPayload, 'posters').map((image) => ({
        ...image,
        season: null,
      }));

      let seasonPosters = [];
      const seasonParam = Number(url.searchParams.get('season'));
      if (
        target.type === 'tv' &&
        Number.isFinite(seasonParam) &&
        seasonParam >= 0
      ) {
        const seasonPayload = await tmdbGet(
          req,
          url,
          `/tv/${target.tmdbId}/season/${seasonParam}/images`,
          { include_image_language: IMAGE_LANGUAGES },
        ).catch(() => null);
        seasonPosters = normalizeImages(seasonPayload, 'posters').map(
          (image) => ({ ...image, season: seasonParam }),
        );
      }

      sendJson(res, 200, {
        ...target,
        details,
        posters,
        backdrops: normalizeImages(seriesPayload, 'backdrops'),
        logos: normalizeImages(seriesPayload, 'logos'),
        seasonPosters,
      });
      return;
    }

    if (url.pathname === '/api/tmdb/search') {
      const query = (url.searchParams.get('q') ?? '').trim();
      const type = url.searchParams.get('type') === 'movie' ? 'movie' : 'tv';
      if (!query) {
        sendJson(res, 200, { results: [] });
        return;
      }
      const payload = await tmdbGet(req, url, `/search/${type}`, {
        query,
        include_adult: 'false',
        language: url.searchParams.get('language') ?? 'es-ES',
      });
      const results = (payload.results ?? []).slice(0, 12).map((item) => ({
        tmdbId: item.id,
        type,
        name: item.name ?? item.title ?? '',
        originalName: item.original_name ?? item.original_title ?? '',
        year: Number(
          (item.first_air_date ?? item.release_date ?? '').slice(0, 4),
        ) || null,
        posterUrl: item.poster_path
          ? `https://image.tmdb.org/t/p/w185${item.poster_path}`
          : null,
      }));
      sendJson(res, 200, { results });
      return;
    }

    if (url.pathname === '/api/health') {
      sendJson(res, 200, {
        ok: true,
        assetsPath: path.relative(ROOT, ASSETS_JSON),
        mapPath: path.relative(ROOT, ID_MAP_JSON),
      });
      return;
    }

    // ---- Static --------------------------------------------------------
    await serveStatic(req, res, url);
  } catch (error) {
    console.error('[asset-studio]', error);
    sendError(res, 500, error?.message ?? 'Unexpected error');
  }
});

server.on('error', (error) => {
  if (error.code === 'EADDRINUSE') {
    console.error(
      `\nPort ${PORT} is already in use. Close the other process or run with another port:\n` +
        `  PORT=3344 node tools/asset-studio/server.mjs\n`,
    );
    process.exit(1);
  }
  throw error;
});

server.listen(PORT, HOST, async () => {
  const catalog = await readCatalog().catch(() => ({}));
  console.log('');
  console.log('  Aniting Asset Studio');
  console.log(`  UI          http://${HOST}:${PORT}`);
  console.log(`  Catalog     ${path.relative(ROOT, ASSETS_JSON)} (${Object.keys(catalog).length} entries)`);
  console.log(`  ID map      ${path.relative(ROOT, ID_MAP_JSON)}`);
  console.log(`  TMDB key    ${process.env.TMDB_API_KEY ? 'from TMDB_API_KEY' : 'project default'}`);
  console.log('');
  console.log('  The Flutter app also reads /api/assets from this port, so a save');
  console.log('  shows up in the desktop build without restarting it.');
  console.log('');
});
