/// <reference path="./onlinestream-provider.d.ts" />

const BASE_URL = "https://ani.pm";
const UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36";

class Provider {

    getSettings(): Settings {
        return {
            episodeServers: ["AniPM (Sub)", "AniPM (Dub)"],
            supportsDub: true,
        };
    }

    private async doFetch(url: string, extraHeaders?: Record<string, string>): Promise<string> {
        const headers: Record<string, string> = {
            "User-Agent": UA,
            "Referer": `${BASE_URL}/`,
        };

        if (extraHeaders) {
            for (const [k, v] of Object.entries(extraHeaders)) {
                headers[k] = v;
            }
        }

        const res = await fetch(url, { headers });
        if (!res) throw new Error(`Fetch returned undefined for ${url}`);
        if (!res.ok) throw new Error(`HTTP ${res.status} for ${url}`);
        return await res.text();
    }

    // ── SEARCH ──────────────────────────────────────────────────────────

    async search(opts: SearchOptions): Promise<SearchResult[]> {
        console.log(`[AniPM] search query="${opts.query}" dub=${opts.dub} anilistId=${opts.media?.id}`);

        // 1. Direct AniList ID Lookup (Instant 0ms exact match)
        if (opts.media && opts.media.id) {
            try {
                const lookupRaw = await this.doFetch(`${BASE_URL}/api/partner/v1/lookup?anilist=${opts.media.id}`);
                const lookupData = JSON.parse(lookupRaw);
                const item = lookupData.data?.[0];

                if (item && item.available) {
                    console.log(`[AniPM] Exact match found for AniList ID ${opts.media.id}: "${item.title}"`);
                    return [{
                        id: String(item.anilistId),
                        title: item.title || opts.media.romajiTitle || opts.query,
                        url: `https://ani.pm/ani/${item.anilistId}`,
                        subOrDub: (item.episodes?.dub > 0) ? "both" : "sub"
                    }];
                }
            } catch (e: any) {
                console.log(`[AniPM] AniList ID lookup error: ${e.message}`);
            }
        }

        // 2. Direct MyAnimeList ID Lookup
        if (opts.media && opts.media.idMal) {
            try {
                const lookupRaw = await this.doFetch(`${BASE_URL}/api/partner/v1/lookup?mal=${opts.media.idMal}`);
                const lookupData = JSON.parse(lookupRaw);
                const item = lookupData.data?.[0];

                if (item && item.available) {
                    console.log(`[AniPM] Exact match found for MAL ID ${opts.media.idMal}: "${item.title}"`);
                    return [{
                        id: String(item.anilistId || item.malId),
                        title: item.title || opts.media.romajiTitle || opts.query,
                        url: `https://ani.pm/ani/${item.anilistId}`,
                        subOrDub: (item.episodes?.dub > 0) ? "both" : "sub"
                    }];
                }
            } catch (e: any) {
                console.log(`[AniPM] MAL ID lookup error: ${e.message}`);
            }
        }

        // 3. Fallback: Search by Title Query
        try {
            const query = opts.query || opts.media?.romajiTitle || opts.media?.englishTitle || "";
            if (!query || query.length < 2) return [];

            const titlesRaw = await this.doFetch(`${BASE_URL}/api/partner/v1/titles?q=${encodeURIComponent(query)}`);
            const titlesData = JSON.parse(titlesRaw);

            if (!titlesData.data || !Array.isArray(titlesData.data)) return [];

            return titlesData.data.map((item: any) => ({
                id: String(item.anilistId || item.malId),
                title: item.title,
                url: item.url || `https://ani.pm/ani/${item.anilistId}`,
                subOrDub: (item.episodes?.dub > 0) ? "both" : "sub"
            }));
        } catch (e: any) {
            console.error(`[AniPM] Titles search error: ${e.message}`);
            return [];
        }
    }

    // ── FIND EPISODES ───────────────────────────────────────────────────

    async findEpisodes(id: string): Promise<EpisodeDetails[]> {
        console.log(`[AniPM] findEpisodes for ID=${id}`);
        try {
            const raw = await this.doFetch(`${BASE_URL}/api/partner/v1/series/${id}`);
            const res = JSON.parse(raw);
            const episodeList = res.data?.episodeList;

            if (!episodeList || !Array.isArray(episodeList)) {
                console.warn(`[AniPM] No episodes list returned for ${id}`);
                return [];
            }

            return episodeList.map((ep: any) => ({
                id: `${id}$${ep.number}`,
                number: ep.number,
                url: `https://ani.pm/embed/ani/${id}/${ep.number}/sub`,
                title: ep.title ? `Episodio ${ep.number} - ${ep.title}` : `Episodio ${ep.number}`
            }));
        } catch (e: any) {
            console.error(`[AniPM] findEpisodes error: ${e.message}`);
            return [];
        }
    }

    // ── FIND EPISODE SERVER ─────────────────────────────────────────────

    async findEpisodeServer(episode: EpisodeDetails, server: string): Promise<EpisodeServer> {
        console.log(`[AniPM] findEpisodeServer: server="${server}" ep=${episode.number} id=${episode.id}`);

        const emptyServer: EpisodeServer = {
            server: server || "AniPM",
            headers: {},
            videoSources: []
        };

        try {
            // Parse anime ID and episode number
            const parts = episode.id.split("$");
            const anilistId = parts[0];
            const epNum = parts[1] || String(episode.number);

            // Determine sub or dub
            const isDub = server.toLowerCase().includes("dub");
            const lang = isDub ? "dub" : "sub";

            // Step 1: Fetch embed player page to retrieve session nonce
            const embedUrl = `${BASE_URL}/embed/ani/${anilistId}/${epNum}/${lang}`;
            const embedHtml = await this.doFetch(embedUrl, {
                "Referer": `${BASE_URL}/`
            });

            const configMatch = embedHtml.match(/id="anipm-embed-config">([^<]+)<\/script>/);
            if (!configMatch) {
                console.error("[AniPM] Could not find embed config nonce");
                return emptyServer;
            }

            const embedConfig = JSON.parse(configMatch[1]);
            const nonce = embedConfig.nonce;
            if (!nonce) {
                console.error("[AniPM] Nonce was missing from embed config");
                return emptyServer;
            }

            // Step 2: Request partner session token
            const sessionUrl = `${BASE_URL}/api/partner/v1/session?n=${encodeURIComponent(nonce)}&id=${anilistId}&ep=${epNum}&lang=${lang}&hardsub=0&adult=1`;
            const sessionRaw = await this.doFetch(sessionUrl, {
                "Referer": `${BASE_URL}/`
            });
            const sessionData = JSON.parse(sessionRaw);

            const token = sessionData.token;
            if (!token) {
                console.error("[AniPM] No session token returned");
                return emptyServer;
            }

            // Step 3: Fetch video manifest and subtitles from player engine (Settlar)
            const settlarUrl = `https://embed.settlar.io/api/embed/session?t=${encodeURIComponent(token)}`;
            const settlarRaw = await this.doFetch(settlarUrl, {
                "Referer": "https://embed.settlar.io/",
                "Accept": "application/json"
            });
            const settlarData = JSON.parse(settlarRaw);

            if (!settlarData.source) {
                console.error("[AniPM] No video stream source URL in settlar response");
                return emptyServer;
            }

            // Format subtitles
            const subtitles: VideoSubtitle[] = (settlarData.subtitles || []).map((sub: any) => ({
                id: sub.srclang || sub.label,
                url: sub.url,
                language: sub.label || sub.srclang || "Unknown",
                isDefault: !!sub.default || sub.srclang === "es" || sub.srclang === "en"
            }));

            // Construct final EpisodeServer
            return {
                server: server || (isDub ? "AniPM (Dub)" : "AniPM (Sub)"),
                headers: {
                    "Referer": "https://embed.settlar.io/",
                    "User-Agent": UA
                },
                videoSources: [
                    {
                        url: settlarData.source,
                        type: "m3u8",
                        quality: "auto",
                        label: isDub ? "Dub" : "Sub",
                        subtitles: subtitles
                    }
                ]
            };
        } catch (e: any) {
            console.error(`[AniPM] findEpisodeServer error: ${e.message}`);
            return emptyServer;
        }
    }
}
