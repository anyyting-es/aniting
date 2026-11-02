/**
 * Aniting Asset Studio — front-end.
 * Vanilla JS, no build step. Talks to ./server.mjs.
 */

const $ = (selector, root = document) => root.querySelector(selector);
const $$ = (selector, root = document) => [...root.querySelectorAll(selector)];

const SLOT_TO_KIND = { poster: 'posters', background: 'backdrops', logo: 'logos' };
const KIND_TO_SLOT = { posters: 'poster', backdrops: 'background', logos: 'logo' };
const KIND_LABEL = { posters: 'Posters', backdrops: 'Backgrounds', logos: 'Logos' };
const SLOT_LABEL = { poster: 'Poster', background: 'Background', logo: 'Logo' };
const TMDB_STORAGE = 'aniting.assetStudio.tmdbKey';
const TMDB_ORIGINAL = 'https://image.tmdb.org/t/p/original';

const state = {
  catalog: {},
  catalogPath: 'assets/data/custom_anime_assets.json',
  mediaById: new Map(),
  selected: null,
  tmdb: null,
  override: null,
  images: null,
  season: null,
  filters: { posters: 'all', backdrops: 'all', logos: 'all' },
  searchResults: [],
  searchQuery: '',
  searchLoading: false,
  searchError: null,
  resultsVisible: false,
  tmdbCandidates: [],
};

let badgeTimer = null;
let toastTimer = null;
let searchTimer = null;

// ---------------------------------------------------------------------------
// Utilities
// ---------------------------------------------------------------------------

const ESCAPES = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' };
const escapeHtml = (value) => String(value ?? '').replace(/[&<>"']/g, (c) => ESCAPES[c]);
const escapeAttr = escapeHtml;

function normalizeUrl(value) {
  if (!value) return '';
  const trimmed = String(value).trim();
  if (/^https?:\/\//i.test(trimmed)) return trimmed;
  return `${TMDB_ORIGINAL}/${trimmed.replace(/^\/+/, '')}`;
}

function htmlToElement(html) {
  const template = document.createElement('template');
  template.innerHTML = html.trim();
  return template.content.firstElementChild;
}

function mediaTitle(media) {
  const title = media?.title ?? {};
  return title.english || title.romaji || title.native || '';
}

function currentEntry() {
  return state.selected ? state.catalog[state.selected.id] ?? {} : {};
}

function currentSlotValue(slot) {
  const entry = currentEntry();
  return entry[slot] ?? '';
}

function guessSeason(seasons, media) {
  if (!Array.isArray(seasons) || seasons.length === 0) return null;
  const year = Number(media?.seasonYear);
  const ordered = [...seasons].sort((a, b) => a.number - b.number);
  if (Number.isFinite(year)) {
    const byYear = ordered.find(
      (season) =>
        season.number > 0 &&
        season.airDate &&
        Number(String(season.airDate).slice(0, 4)) === year,
    );
    if (byYear) return byYear.number;
  }
  const first = ordered.find((season) => season.number === 1);
  if (first) return 1;
  const firstRegular = ordered.find((season) => season.number > 0);
  return firstRegular ? firstRegular.number : ordered[0].number;
}

const languageNames = (() => {
  try {
    return new Intl.DisplayNames(['es'], { type: 'language' });
  } catch {
    return null;
  }
})();

function languageName(code) {
  if (!code) return 'Sin idioma (textless)';
  try {
    const name = languageNames?.of(code);
    return name ? name.charAt(0).toUpperCase() + name.slice(1) : code.toUpperCase();
  } catch {
    return code.toUpperCase();
  }
}

// ---------------------------------------------------------------------------
// API
// ---------------------------------------------------------------------------

function tmdbKey() {
  return localStorage.getItem(TMDB_STORAGE)?.trim() ?? '';
}

async function api(path, options = {}) {
  const headers = { ...(options.headers ?? {}) };
  if (options.body) headers['Content-Type'] = 'application/json';
  const key = tmdbKey();
  if (key) headers['X-Tmdb-Key'] = key;

  const response = await fetch(path, { ...options, headers });
  const raw = await response.text();
  let data = null;
  try {
    data = raw ? JSON.parse(raw) : null;
  } catch {
    data = null;
  }
  if (!response.ok) {
    throw new Error(data?.error ?? `HTTP ${response.status}`);
  }
  return data;
}

// ---------------------------------------------------------------------------
// Chrome (badge / toast)
// ---------------------------------------------------------------------------

function updateSaveBadge(kind, text) {
  const badge = $('#save-badge');
  if (!badge) return;
  badge.className = 'save-badge' + (kind ? ` is-${kind}` : '');
  badge.textContent = text;
  clearTimeout(badgeTimer);
  if (kind === 'saved') {
    badgeTimer = setTimeout(() => updateSaveBadge('', 'Listo'), 1800);
  } else if (kind === 'error') {
    badgeTimer = setTimeout(() => updateSaveBadge('', 'Listo'), 5000);
  }
}

function toast(message, isError = false) {
  const element = $('#toast');
  if (!element) return;
  element.textContent = message;
  element.className = 'toast show' + (isError ? ' is-error' : '');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => {
    element.className = 'toast';
  }, 2400);
}

// ---------------------------------------------------------------------------
// Catalog
// ---------------------------------------------------------------------------

async function loadCatalog() {
  const data = await api('/api/catalog');
  state.catalog = data?.catalog ?? {};
  if (data?.path) state.catalogPath = data.path;
  const pathLabel = $('#catalog-path');
  if (pathLabel) pathLabel.textContent = state.catalogPath;
  updateCatalogCounts();
  renderCatalog();
}

function updateCatalogCounts() {
  const entries = Object.entries(state.catalog);
  const complete = entries.filter(([, entry]) =>
    ['background', 'logo', 'poster'].every((slot) => !!entry?.[slot]),
  ).length;
  const count = $('#catalog-count');
  if (count) count.textContent = String(entries.length);
  const foot = $('#catalog-foot');
  if (foot) foot.textContent = `${complete}/${entries.length} con arte completo`;
}

async function hydrateCatalogNames() {
  const missing = Object.keys(state.catalog)
    .map(Number)
    .filter((id) => Number.isFinite(id) && id > 0 && !state.mediaById.has(id));
  if (missing.length === 0) return;
  try {
    const data = await api('/api/anilist/batch', {
      method: 'POST',
      body: JSON.stringify({ ids: missing }),
    });
    for (const media of data?.media ?? []) {
      if (media?.id) state.mediaById.set(media.id, media);
    }
    renderCatalog();
  } catch {
    // AniList down: the sidebar still works with raw IDs.
  }
}

function renderCatalog() {
  const list = $('#catalog-list');
  if (!list) return;

  const filter = ($('#catalog-filter')?.value ?? '').trim().toLowerCase();
  const rows = Object.entries(state.catalog)
    .map(([id, entry]) => {
      const numericId = Number(id);
      const media = state.mediaById.get(numericId);
      return {
        id: numericId,
        entry,
        media,
        title: mediaTitle(media) || `AniList #${numericId}`,
      };
    })
    .filter(({ id, title }) => {
      if (!filter) return true;
      if (String(id).includes(filter)) return true;
      if (title.toLowerCase().includes(filter)) return true;
      const secondary = [
        state.mediaById.get(id)?.title?.romaji,
        state.mediaById.get(id)?.title?.native,
      ]
        .filter(Boolean)
        .join(' ')
        .toLowerCase();
      return secondary.includes(filter);
    })
    .sort((a, b) => {
      if (a.title && b.title) return a.title.localeCompare(b.title);
      return a.id - b.id;
    });

  if (rows.length === 0) {
    list.innerHTML = '<li class="muted" style="padding:14px 10px">Sin coincidencias.</li>';
    return;
  }

  list.innerHTML = rows
    .map(({ id, entry, media, title }) => {
      const poster = entry.poster
        ? normalizeUrl(entry.poster)
        : media?.coverImage?.large || '';
      const dots = ['poster', 'background', 'logo']
        .map((slot) => `<span class="dot ${entry[slot] ? 'on' : ''}"></span>`)
        .join('');
      const active = state.selected?.id === id ? ' is-active' : '';
      return `<li>
        <button class="catalog-item${active}" data-catalog-id="${id}" title="${escapeAttr(title)}">
          ${
            poster
              ? `<img class="catalog-thumb" src="${escapeAttr(poster)}" alt="" loading="lazy">`
              : '<div class="catalog-thumb"></div>'
          }
          <span class="catalog-meta">
            <strong>${escapeHtml(title)}</strong>
            <span>ID ${id}${entry.poster ? '' : ' · sin poster'}</span>
          </span>
          <span class="catalog-dots">${dots}</span>
        </button>
      </li>`;
    })
    .join('');
}

// ---------------------------------------------------------------------------
// Stage
// ---------------------------------------------------------------------------

function emptyHtml() {
  return `<div class="empty-state">
    <div class="empty-art">✦</div>
    <h1>Curador de arte y metadata</h1>
    <p>Busca un anime en AniList o elige uno del catálogo. Las imágenes se sirven
      directo al reproductor desde <code>custom_anime_assets.json</code>, sin
      llamadas extra a TMDB.</p>
    <div class="empty-tips">
      <span>Clic en una imagen → se guarda al instante</span>
      <span>Poster · Background · Logo</span>
      <span>Filtra por idioma o sin idioma</span>
    </div>
  </div>`;
}

function resultsHtml() {
  if (state.searchLoading) {
    return `<div class="loader"><span class="spinner"></span> Buscando “${escapeHtml(
      state.searchQuery,
    )}” en AniList…</div>`;
  }
  if (state.searchError) {
    return `<div class="results"><div class="notice">Error de AniList: <strong>${escapeHtml(
      state.searchError,
    )}</strong></div></div>`;
  }
  if (state.searchResults.length === 0) {
    return `<div class="results"><div class="notice">Sin resultados para
      <strong>${escapeHtml(state.searchQuery)}</strong>.</div></div>`;
  }

  const cards = state.searchResults
    .map((media) => {
      const title = mediaTitle(media) || `AniList #${media.id}`;
      const cover = media.coverImage?.large ?? media.coverImage?.extraLarge ?? '';
      const meta = [media.format, media.seasonYear, media.episodes ? `${media.episodes} eps` : null]
        .filter(Boolean)
        .join(' · ');
      const inCatalog = state.catalog[media.id] ? ' · custom' : '';
      return `<button class="result-card" data-search-id="${media.id}">
        ${
          cover
            ? `<img src="${escapeAttr(cover)}" alt="" loading="lazy">`
            : '<div class="rc-cover-placeholder"></div>'
        }
        <span class="rc-meta">
          <strong>${escapeHtml(title)}</strong>
          <span>${escapeHtml(meta)} · ID ${media.id}${inCatalog}</span>
        </span>
      </button>`;
    })
    .join('');

  return `<div class="results">
    <div class="results-head">
      <h2>Resultados para “${escapeHtml(state.searchQuery)}”</h2>
      <span class="muted">${state.searchResults.length} resultados · clic para editar</span>
    </div>
    <div class="results-grid">${cards}</div>
  </div>`;
}

function renderStage() {
  const stage = $('#stage');
  if (!stage) return;
  if (state.selected) {
    stage.innerHTML = editorHtml();
  } else if (state.resultsVisible) {
    stage.innerHTML = resultsHtml();
  } else {
    stage.innerHTML = emptyHtml();
  }
}

// ---------------------------------------------------------------------------
// Editor
// ---------------------------------------------------------------------------

function heroHtml(media) {
  const titles = media.title ?? {};
  const title = mediaTitle(media) || `AniList #${media.id}`;
  const secondary = [titles.romaji, titles.native]
    .filter((value) => value && value !== title)
    .join(' · ');
  const banner = media.bannerImage ?? '';
  const poster = media.coverImage?.extraLarge ?? media.coverImage?.large ?? '';
  const entry = state.catalog[media.id] ?? {};
  const complete = ['background', 'logo', 'poster'].filter((slot) => entry[slot]).length;

  const chips = [
    media.format,
    media.seasonYear,
    media.episodes ? `${media.episodes} eps` : null,
    media.status,
    ...(media.genres ?? []).slice(0, 3),
  ]
    .filter(Boolean)
    .map((value, index) => `<span class="chip${index === 0 ? ' accent' : ''}">${escapeHtml(value)}</span>`)
    .join('');

  const tmdb = state.tmdb;
  const tmdbLink =
    tmdb?.tmdbId && tmdb?.type
      ? `<a href="https://www.themoviedb.org/${tmdb.type}/${tmdb.tmdbId}" target="_blank" rel="noreferrer">TMDB #${tmdb.tmdbId} ↗</a>`
      : '';
  const aniListLink = `<a href="${escapeAttr(
    media.siteUrl ?? `https://anilist.co/anime/${media.id}`,
  )}" target="_blank" rel="noreferrer">AniList #${media.id} ↗</a>`;

  return `<div class="hero">
    ${banner ? `<div class="hero-bg" style="background-image:url('${escapeAttr(banner)}')"></div>` : ''}
    <div class="hero-shade"></div>
    <div class="hero-body">
      ${poster ? `<img class="hero-poster" src="${escapeAttr(poster)}" alt="">` : ''}
      <div class="hero-text">
        <div class="eyebrow">AniList #${media.id}${media.idMal ? ` · MAL #${media.idMal}` : ''}</div>
        <h1>${escapeHtml(title)}</h1>
        ${secondary ? `<div class="sub">${escapeHtml(secondary)}</div>` : ''}
        <div class="chips">${chips}</div>
        <div class="hero-links">${aniListLink}${tmdbLink}</div>
      </div>
      <span class="hero-badge${complete === 3 ? '' : ' is-empty'}">
        ${complete === 3 ? 'Custom 3/3' : `Custom ${complete}/3`}
      </span>
    </div>
  </div>`;
}

function slotsHtml() {
  const entry = currentEntry();
  return ['poster', 'background', 'logo']
    .map((slot) => {
      const value = entry[slot] ?? '';
      const has = !!value;
      const isLogo = slot === 'logo';
      return `<div class="slot" id="slot-card-${slot}">
        <div class="slot-head">
          ${SLOT_LABEL[slot]}
          <span class="state${has ? ' on' : ''}">${has ? 'Guardado' : 'Sin definir'}</span>
        </div>
        <div class="slot-preview${isLogo ? ' is-logo' : ''}">
          ${
            has
              ? `<img src="${escapeAttr(normalizeUrl(value))}" alt="" loading="lazy">`
              : '<span class="no-image">Sin imagen</span>'
          }
        </div>
        <div class="slot-body">
          <input id="slot-${slot}-url" value="${escapeAttr(value)}" placeholder="https://… o archivo.jpg" spellcheck="false" />
          <div class="slot-actions">
            <button class="mini-btn" data-slot-apply="${slot}">Aplicar URL</button>
            <button class="mini-btn danger" data-slot-clear="${slot}">Quitar</button>
          </div>
        </div>
      </div>`;
    })
    .join('');
}

function tmdbBarHtml() {
  const tmdb = state.tmdb;
  const has = !!tmdb?.tmdbId;
  const details = tmdb?.details;
  const label = has
    ? `<span class="dot on"></span><strong>${escapeHtml(
        details?.name ?? `TMDB #${tmdb.tmdbId}`,
      )}</strong><span>· ${tmdb.type === 'movie' ? 'película' : 'serie'} #${tmdb.tmdbId}${
        tmdb.source === 'manual' ? ' (manual)' : ''
      }</span>`
    : `<span class="dot off"></span><strong>Sin TMDB en el mapa</strong>${
        tmdb?.tvdbId ? `<span>· TVDB #${tmdb.tvdbId}</span>` : ''
      }`;

  const link = has
    ? `<a href="https://www.themoviedb.org/${tmdb.type}/${tmdb.tmdbId}" target="_blank" rel="noreferrer">Abrir ↗</a>`
    : '';

  const media = state.selected;
  const defaultType = tmdb?.type ?? (media?.format === 'MOVIE' ? 'movie' : 'tv');
  const query = mediaTitle(media);

  return `<div class="tmdb-bar">
    ${label}
    ${link}
    <details class="tmdb-switch"${has ? '' : ' open'}>
      <summary>Cambiar TMDB</summary>
      <div class="switch-body">
        <select id="tmdb-type">
          <option value="tv"${defaultType === 'tv' ? ' selected' : ''}>Serie</option>
          <option value="movie"${defaultType === 'movie' ? ' selected' : ''}>Película</option>
        </select>
        <input id="tmdb-query" value="${escapeAttr(query)}" placeholder="Buscar en TMDB…" />
        <button class="ghost-btn" data-tmdb-search>Buscar</button>
        <input id="tmdb-manual-id" type="number" min="1" placeholder="ID manual" style="width:110px" />
        <button class="ghost-btn" data-tmdb-manual>Usar ID</button>
        ${state.override ? '<button class="ghost-btn" data-tmdb-reset>Volver al mapa</button>' : ''}
      </div>
      <div id="tmdb-candidates" class="tmdb-candidates">${candidatesHtml()}</div>
    </details>
  </div>`;
}

function candidatesHtml() {
  if (!state.tmdbCandidates.length) return '';
  return state.tmdbCandidates
    .map(
      (candidate) => `<button class="candidate" data-tmdb-pick data-type="${escapeAttr(
        candidate.type,
      )}" data-id="${candidate.tmdbId}">
        ${
          candidate.posterUrl
            ? `<img src="${escapeAttr(candidate.posterUrl)}" alt="" loading="lazy">`
            : ''
        }
        <span>
          <strong>${escapeHtml(candidate.name || `#${candidate.tmdbId}`)}</strong><br>
          ${escapeHtml(
            [candidate.type === 'movie' ? 'película' : 'serie', candidate.year, `#${candidate.tmdbId}`]
              .filter(Boolean)
              .join(' · '),
          )}
        </span>
      </button>`,
    )
    .join('');
}

function languageOptions(images) {
  const counts = new Map();
  for (const image of images) {
    const key = image.language ?? 'none';
    counts.set(key, (counts.get(key) ?? 0) + 1);
  }
  const options = [{ value: 'all', label: 'Todos', count: images.length }];
  if (counts.has('none')) {
    options.push({ value: 'none', label: 'Sin idioma', count: counts.get('none') });
  }
  [...counts.keys()]
    .filter((key) => key !== 'none')
    .sort()
    .forEach((key) => {
      options.push({ value: key, label: key.toUpperCase(), count: counts.get(key) });
    });
  return options;
}

function previewUrl(kind, image) {
  const size = kind === 'posters' ? 'w185' : 'w300';
  return `https://image.tmdb.org/t/p/${size}${image.filePath}`;
}

function imageCardHtml(kind, image, selectedValue) {
  const selected = normalizeUrl(image.url) === normalizeUrl(selectedValue);
  const language = image.language ?? 'none';
  const langTag = `<span class="lang-tag${language === 'none' ? ' none' : ''}" title="${escapeAttr(
    languageName(image.language),
  )}">${language === 'none' ? '—' : escapeHtml(language.toUpperCase())}</span>`;
  const seasonTag =
    image.season != null ? `<span class="season-tag">T${escapeHtml(image.season)}</span>` : '';
  return `<button class="img-card${selected ? ' is-selected' : ''}"
      data-pick data-kind="${kind}" data-url="${escapeAttr(image.url)}"
      title="${escapeAttr(`${image.width ?? '?'}×${image.height ?? '?'} · ${languageName(image.language)} · ★ ${Number(
        image.voteAverage ?? 0,
      ).toFixed(1)}`)}">
    <img loading="lazy" src="${escapeAttr(previewUrl(kind, image))}" alt="">
    ${langTag}${seasonTag}
    <span class="check">✓</span>
    <span class="file-name">${escapeHtml(image.filePath)}</span>
  </button>`;
}

function seasonSelectHtml() {
  const tmdb = state.tmdb;
  if (tmdb?.type !== 'tv') return '';
  const seasons = (tmdb.details?.seasons ?? state.images?.details?.seasons ?? []).filter(
    (season) => Number.isFinite(season.number),
  );
  if (seasons.length === 0) return '';
  return `<select class="season-select" data-season-select title="Posters de temporada">
    <option value=""${state.season == null ? ' selected' : ''}>Serie (todas)</option>
    ${seasons
      .map(
        (season) =>
          `<option value="${season.number}"${
            state.season === season.number ? ' selected' : ''
          }>T${season.number}${
            season.episodeCount ? ` · ${season.episodeCount} eps` : ''
          }</option>`,
      )
      .join('')}
  </select>`;
}

function seasonStripHtml() {
  const images = state.images?.seasonPosters ?? [];
  if (images.length === 0) return '';
  const filter = state.filters.posters;
  const filtered =
    filter === 'all'
      ? images
      : images.filter((image) => (image.language ?? 'none') === filter);
  if (filtered.length === 0) return '';
  const selectedValue = currentSlotValue('poster');
  return `<div class="season-strip">
    <div class="season-strip-head">
      <strong>Temporada ${state.season}</strong>
      <span>posters de la temporada en TMDB</span>
    </div>
    <div class="grid posters">
      ${filtered.map((image) => imageCardHtml('posters', image, selectedValue)).join('')}
    </div>
  </div>`;
}

function pickerHtml(kind) {
  const all = state.images?.[kind] ?? [];
  const filter = state.filters[kind];
  const filtered =
    filter === 'all' ? all : all.filter((image) => (image.language ?? 'none') === filter);
  const selectedValue = currentSlotValue(KIND_TO_SLOT[kind]);
  const options = languageOptions(all);

  const chips = options
    .map(
      (option) =>
        `<button class="lang-chip${option.value === filter ? ' is-active' : ''}"
          data-lang-kind="${kind}" data-lang="${escapeAttr(option.value)}"
          title="${escapeAttr(option.value === 'all' ? 'Todos los idiomas' : option.value === 'none' ? 'Sin texto (textless)' : languageName(option.value))}"
        >${escapeHtml(option.label)}${
          option.value === 'all' ? '' : ` · ${option.count}`
        }</button>`,
    )
    .join('');

  const cards = filtered
    .map((image) => imageCardHtml(kind, image, selectedValue))
    .join('');

  return `<section class="picker" id="picker-${kind}">
    <div class="picker-head">
      <h3>${KIND_LABEL[kind]}</h3>
      <span class="count">${filtered.length} de ${all.length}</span>
      ${kind === 'posters' ? seasonSelectHtml() : ''}
      <div class="lang-chips">${chips}</div>
    </div>
    <div class="picker-body">
      ${kind === 'posters' ? seasonStripHtml() : ''}
      ${
        cards
          ? `<div class="grid ${kind}">${cards}</div>`
          : `<div class="notice">No hay imágenes para este filtro.</div>`
      }
    </div>
  </section>`;
}

function editorHtml() {
  const media = state.selected;
  const pickers = state.images
    ? ['posters', 'backdrops', 'logos'].map(pickerHtml).join('')
    : `<div class="loader"><span class="spinner"></span> Cargando imágenes de TMDB…</div>`;

  const missingTmdb =
    state.images && (!state.tmdb?.tmdbId || (state.images.posters?.length ?? 0) === 0);

  return `<div class="editor">
    ${heroHtml(media)}
    <div class="section">
      <div class="section-head">
        <h2>Custom metadata</h2>
        <span class="hint">Se guarda directo en ${escapeHtml(state.catalogPath)}</span>
      </div>
      <div class="slots" id="slots">${slotsHtml()}</div>
    </div>
    <div class="section">
      <div class="section-head">
        <h2>Imágenes de TMDB</h2>
        <span class="hint">Clic para elegir · se guarda automáticamente</span>
      </div>
      ${tmdbBarHtml()}
      ${
        missingTmdb
          ? `<div class="notice" style="margin-top:12px">
              Este ID no tiene TMDB en <code>anilist_tmdb_map.json</code>. Abre
              <strong>Cambiar TMDB</strong> y busca el show (o pon el ID a mano) para
              cargar sus imágenes.
            </div>`
          : ''
      }
      ${pickers}
    </div>
  </div>`;
}

// ---------------------------------------------------------------------------
// TMDB loading
// ---------------------------------------------------------------------------

async function loadTmdbTarget() {
  const media = state.selected;
  if (!media) return;
  state.tmdb = null;
  state.season = null;
  try {
    const resolve = await api(`/api/tmdb/resolve?anilistId=${media.id}`);
    state.tmdb = resolve;
    if (resolve.tmdbId) {
      const details = await api(`/api/tmdb/details?anilistId=${media.id}`).catch(() => null);
      state.tmdb = { ...resolve, details: details?.details ?? null };
      state.season = guessSeason(details?.details?.seasons, media);
    }
  } catch (error) {
    state.tmdb = { tmdbId: 0, type: null, source: 'none', error: error.message };
  }
}

async function loadImages({ allowSeasonGuess = true } = {}) {
  const media = state.selected;
  if (!media) return;

  const params = new URLSearchParams();
  if (state.override) {
    params.set('type', state.override.type);
    params.set('id', String(state.override.id));
  } else {
    params.set('anilistId', String(media.id));
  }
  if (state.season != null) params.set('season', String(state.season));

  const data = await api(`/api/tmdb/images?${params.toString()}`);
  state.images = data;

  if (data?.tmdbId) {
    state.tmdb = {
      ...(state.tmdb ?? {}),
      tmdbId: data.tmdbId,
      type: data.type,
      tvdbId: data.tvdbId ?? state.tmdb?.tvdbId ?? null,
      details: data.details ?? state.tmdb?.details ?? null,
      source: state.override ? 'manual' : state.tmdb?.source ?? 'map',
      error: null,
    };
  }

  if (allowSeasonGuess && state.season == null) {
    const guessed = guessSeason(data?.details?.seasons, media);
    if (guessed != null) {
      state.season = guessed;
      return loadImages({ allowSeasonGuess: false });
    }
  }
}

async function applyTmdbOverride(type, id) {
  state.override = { type, id };
  state.season = null;
  state.images = null;
  state.tmdb = null;
  updateSaveBadge('saving', 'Cargando TMDB…');
  renderStage();
  try {
    await loadImages();
    renderStage();
    toast(`TMDB #${id} cargado`);
    updateSaveBadge('', 'Listo');
  } catch (error) {
    updateSaveBadge('error', 'Error TMDB');
    toast(`TMDB: ${error.message}`, true);
    renderStage();
  }
}

async function searchTmdb() {
  const type = $('#tmdb-type')?.value === 'movie' ? 'movie' : 'tv';
  const query = ($('#tmdb-query')?.value ?? '').trim();
  const box = $('#tmdb-candidates');
  if (!query) {
    toast('Escribe un título para buscar en TMDB', true);
    return;
  }
  if (box) box.innerHTML = '<div class="loader"><span class="spinner"></span> Buscando en TMDB…</div>';
  try {
    const data = await api(`/api/tmdb/search?type=${type}&q=${encodeURIComponent(query)}`);
    state.tmdbCandidates = data?.results ?? [];
    if (box) box.innerHTML = candidatesHtml() || '<div class="notice">Sin resultados.</div>';
  } catch (error) {
    if (box) box.innerHTML = `<div class="notice">${escapeHtml(error.message)}</div>`;
  }
}

// ---------------------------------------------------------------------------
// Media opening / searching
// ---------------------------------------------------------------------------

async function openMedia(media) {
  if (!media?.id) return;
  state.selected = media;
  state.mediaById.set(media.id, media);
  state.override = null;
  state.images = null;
  state.tmdb = null;
  state.season = null;
  state.tmdbCandidates = [];
  state.resultsVisible = false;
  state.searchLoading = false;
  state.searchError = null;
  state.filters = { posters: 'all', backdrops: 'all', logos: 'all' };
  renderCatalog();
  renderStage();

  await loadTmdbTarget();
  try {
    await loadImages();
  } catch (error) {
    state.images = { posters: [], backdrops: [], logos: [], seasonPosters: [], error: error.message };
    toast(`No se pudieron cargar las imágenes: ${error.message}`, true);
  }
  renderStage();
}

async function openCatalogEntry(id) {
  const numericId = Number(id);
  if (!Number.isFinite(numericId) || numericId <= 0) return;

  let media = state.mediaById.get(numericId) ?? null;
  if (!media) {
    try {
      const data = await api(`/api/anilist/media/${numericId}`);
      media = data?.media ?? null;
    } catch {
      media = null;
    }
  }

  if (!media) {
    const entry = state.catalog[numericId] ?? {};
    media = {
      id: numericId,
      title: { romaji: `AniList #${numericId}` },
      coverImage: { large: entry.poster ? normalizeUrl(entry.poster) : null },
      format: null,
      seasonYear: null,
      episodes: null,
      genres: [],
    };
  }

  await openMedia(media);
}

function scheduleSearch(query) {
  clearTimeout(searchTimer);
  state.searchQuery = query.trim();
  if (state.searchQuery.length < 2) {
    state.resultsVisible = false;
    state.searchResults = [];
    state.searchLoading = false;
    state.searchError = null;
    if (!state.selected) renderStage();
    return;
  }
  searchTimer = setTimeout(() => runSearch(state.searchQuery), 320);
}

async function runSearch(query) {
  state.selected = null;
  state.resultsVisible = true;
  state.searchLoading = true;
  state.searchError = null;
  state.searchResults = [];
  renderStage();
  renderCatalog();

  try {
    const data = await api(`/api/anilist/search?q=${encodeURIComponent(query)}`);
    if (state.searchQuery !== query) return;
    state.searchResults = data?.results ?? [];
  } catch (error) {
    if (state.searchQuery !== query) return;
    state.searchError = error.message;
  } finally {
    if (state.searchQuery === query) {
      state.searchLoading = false;
      renderStage();
    }
  }
}

// ---------------------------------------------------------------------------
// Saving
// ---------------------------------------------------------------------------

async function saveSlot(slot, value) {
  const media = state.selected;
  if (!media) return;

  updateSaveBadge('saving', 'Guardando…');
  try {
    const response = await api('/api/assets', {
      method: 'POST',
      body: JSON.stringify({ id: media.id, [slot]: value }),
    });

    state.catalog = response?.catalog ?? state.catalog;
    if (response?.entry) state.catalog[media.id] = response.entry;
    else delete state.catalog[media.id];

    updateCatalogCounts();
    renderCatalog();
    refreshSlots();
    syncPickerMarks();
    updateSaveBadge('saved', 'Guardado ✓');
    toast(value ? 'Guardado en custom_anime_assets.json' : 'Imagen quitada');
  } catch (error) {
    updateSaveBadge('error', 'Error');
    toast(`No se pudo guardar: ${error.message}`, true);
  }
}

function refreshSlots() {
  const container = $('#slots');
  if (container) container.innerHTML = slotsHtml();
  const heroBadge = $('.hero-badge');
  if (heroBadge) {
    const complete = ['background', 'logo', 'poster'].filter((slot) => currentEntry()[slot]).length;
    heroBadge.className = `hero-badge${complete === 3 ? '' : ' is-empty'}`;
    heroBadge.textContent = complete === 3 ? 'Custom 3/3' : `Custom ${complete}/3`;
  }
}

function syncPickerMarks() {
  const entry = currentEntry();
  $$('[data-pick]').forEach((element) => {
    const slot = KIND_TO_SLOT[element.dataset.kind];
    const isSelected =
      !!entry[slot] && normalizeUrl(element.dataset.url) === normalizeUrl(entry[slot]);
    element.classList.toggle('is-selected', isSelected);
  });
}

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------

function restoreTmdbKey() {
  const saved = localStorage.getItem(TMDB_STORAGE);
  if (saved) $('#tmdb-key').value = saved;
}

function bindEvents() {
  $('#anilist-search')?.addEventListener('input', (event) => {
    scheduleSearch(event.target.value);
  });

  $('#catalog-filter')?.addEventListener('input', () => renderCatalog());

  $('#reload-catalog')?.addEventListener('click', async () => {
    try {
      await loadCatalog();
      await hydrateCatalogNames();
      toast('Catálogo recargado');
    } catch (error) {
      toast(`No se pudo recargar: ${error.message}`, true);
    }
  });

  $('#tmdb-key')?.addEventListener('change', (event) => {
    const value = event.target.value.trim();
    if (value) localStorage.setItem(TMDB_STORAGE, value);
    else localStorage.removeItem(TMDB_STORAGE);
    toast(value ? 'TMDB key guardada en este navegador' : 'Usando la key del proyecto');
  });

  document.addEventListener('click', async (event) => {
    const pick = event.target.closest('[data-pick]');
    if (pick) {
      event.preventDefault();
      await saveSlot(KIND_TO_SLOT[pick.dataset.kind], pick.dataset.url);
      return;
    }

    const catalogItem = event.target.closest('[data-catalog-id]');
    if (catalogItem) {
      await openCatalogEntry(Number(catalogItem.dataset.catalogId));
      return;
    }

    const result = event.target.closest('[data-search-id]');
    if (result) {
      const media = state.searchResults.find(
        (item) => item.id === Number(result.dataset.searchId),
      );
      if (media) await openMedia(media);
      return;
    }

    const langChip = event.target.closest('[data-lang-kind]');
    if (langChip) {
      const kind = langChip.dataset.langKind;
      state.filters[kind] = langChip.dataset.lang;
      const current = $(`#picker-${kind}`);
      if (current) current.replaceWith(htmlToElement(pickerHtml(kind)));
      return;
    }

    const apply = event.target.closest('[data-slot-apply]');
    if (apply) {
      const slot = apply.dataset.slotApply;
      const value = ($(`#slot-${slot}-url`)?.value ?? '').trim();
      await saveSlot(slot, value);
      return;
    }

    const clear = event.target.closest('[data-slot-clear]');
    if (clear) {
      await saveSlot(clear.dataset.slotClear, '');
      return;
    }

    if (event.target.closest('[data-tmdb-search]')) {
      await searchTmdb();
      return;
    }

    if (event.target.closest('[data-tmdb-manual]')) {
      const id = Number($('#tmdb-manual-id')?.value);
      const type = $('#tmdb-type')?.value === 'movie' ? 'movie' : 'tv';
      if (Number.isFinite(id) && id > 0) await applyTmdbOverride(type, id);
      else toast('Escribe un ID de TMDB válido', true);
      return;
    }

    const candidate = event.target.closest('[data-tmdb-pick]');
    if (candidate) {
      await applyTmdbOverride(
        candidate.dataset.type === 'movie' ? 'movie' : 'tv',
        Number(candidate.dataset.id),
      );
      return;
    }

    if (event.target.closest('[data-tmdb-reset]')) {
      if (!state.selected) return;
      state.override = null;
      state.season = null;
      state.images = null;
      state.tmdb = null;
      await openMedia(state.selected);
      return;
    }
  });

  document.addEventListener('change', async (event) => {
    if (event.target.matches('[data-season-select]')) {
      const value = event.target.value;
      state.season = value === '' ? null : Number(value);
      if (!state.selected) return;
      updateSaveBadge('saving', 'Cargando temporada…');
      try {
        await loadImages();
        renderStage();
        updateSaveBadge('', 'Listo');
      } catch (error) {
        updateSaveBadge('error', 'Error');
        toast(error.message, true);
      }
    }
  });

  document.addEventListener('keydown', (event) => {
    if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 'k') {
      event.preventDefault();
      $('#anilist-search')?.focus();
      $('#anilist-search')?.select();
    }
  });
}

// ---------------------------------------------------------------------------
// Boot
// ---------------------------------------------------------------------------

async function boot() {
  restoreTmdbKey();
  bindEvents();

  try {
    await loadCatalog();
  } catch (error) {
    $('#stage').innerHTML = `<div class="results"><div class="notice">
      No se pudo leer el catálogo: <strong>${escapeHtml(error.message)}</strong><br>
      ¿Está corriendo <code>node tools/asset-studio/server.mjs</code>?
    </div></div>`;
    return;
  }

  hydrateCatalogNames();
  updateSaveBadge('', 'Listo');
}

boot();
