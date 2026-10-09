/// <reference path="./online-streaming-provider.d.ts" />

declare type SearchResult = {
    id: string;
    title: string;
    url: string;
    subOrDub: SubOrDub;
};

declare type SubOrDub = "sub" | "dub" | "both";

declare type EpisodeDetails = {
    id: string;
    number: number;
    url: string;
    title?: string;
};

declare type EpisodeServer = {
    server: string;
    headers: {
        [key: string]: string;
    };
    videoSources: VideoSource[];
};

declare type VideoSourceType = "mp4" | "m3u8" | "unknown";

declare type VideoSource = {
    url: string;
    type: VideoSourceType;
    quality: string;
    label?: string;
    subtitles: VideoSubtitle[];
};

declare type VideoSubtitle = {
    id: string;
    url: string;
    language: string;
    isDefault: boolean;
};

declare interface Media {
    id: number;
    idMal?: number;
    status?: string;
    format?: string;
    englishTitle?: string;
    romajiTitle?: string;
    episodeCount?: number;
    absoluteSeasonOffset?: number;
    synonyms: string[];
    isAdult: boolean;
}

declare type SearchOptions = {
    media: Media;
    query: string;
    dub: boolean;
    year?: number;
};

declare type Settings = {
    episodeServers: string[];
    supportsDub: boolean;
};

class Provider {
    baseUrl = "https://jkanime.net";
    userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";

    getSettings(): Settings {
        return {
            episodeServers: ["JK", "StreamWish", "Vidhide", "Mp4upload", "YourUpload", "Voe"],
            supportsDub: false,
        };
    }

    private _cleanId(href: string): string {
        return href
            .replace(this.baseUrl, "")
            .replace(/^\/+/, "")
            .replace(/\/+$/, "");
    }

    private _b64Decode(str: string): string {
        try {
            if (typeof atob === "function") {
                return atob(str.trim());
            }
            if (typeof CryptoJS !== "undefined") {
                const parsed = CryptoJS.enc.Base64.parse(str.trim());
                return CryptoJS.enc.Latin1.stringify(parsed);
            }
        } catch (e) {
            // Ignore
        }
        return "";
    }

    private _unpackJs(html: string): string | null {
        const match = html.match(/eval\(function\(p,a,c,k,e,[rd].*?split\('\|'\)\)\)/);
        if (!match) return null;
        const packed = match[0];
        const m = packed.match(/\}\s*\('([\s\S]*?)',\s*(\d+),\s*(\d+),\s*'([\s\S]*?)'\.split\('\|'\)/);
        if (!m) return null;
        const p = m[1];
        const a = parseInt(m[2], 10);
        const c = parseInt(m[3], 10);
        const k = m[4].split('|');

        const alphabet = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
        const decodeRadix = (word: string, radix: number): number => {
            if (radix <= 36) {
                const val = parseInt(word, radix);
                return isNaN(val) ? -1 : val;
            }
            let res = 0;
            for (let i = 0; i < word.length; i++) {
                const idx = alphabet.indexOf(word[i]);
                if (idx === -1 || idx >= radix) return -1;
                res = res * radix + idx;
            }
            return res;
        };

        return p.replace(/\b\w+\b/g, (w) => {
            const idx = decodeRadix(w, a);
            if (idx >= 0 && idx < k.length && k[idx]) {
                return k[idx];
            }
            return w;
        });
    }

    private _normalizeServerName(name: string): string {
        const n = name.trim().toLowerCase();
        if (n.includes("jk") || n.includes("magi") || n.includes("desu")) return "JK";
        if (n.includes("streamwish") || n.includes("wish")) return "StreamWish";
        if (n.includes("vidhide")) return "Vidhide";
        if (n.includes("mp4upload")) return "Mp4upload";
        if (n.includes("yourupload")) return "YourUpload";
        if (n.includes("voe")) return "Voe";
        return name;
    }

    private _detectServerFromUrl(url: string): string | null {
        const u = url.toLowerCase();
        if (u.includes("jkplayer") || u.includes("playmudos")) return "JK";
        if (u.includes("streamwish") || u.includes("fastwish") || u.includes("wishembed")) return "StreamWish";
        if (u.includes("vidhide")) return "Vidhide";
        if (u.includes("mp4upload")) return "Mp4upload";
        if (u.includes("yourupload")) return "YourUpload";
        if (u.includes("voe.sx") || u.includes("teresapoliticallearn")) return "Voe";
        return null;
    }

    async search(opts: SearchOptions): Promise<SearchResult[]> {
        const queries: string[] = [];
        if (opts.query && opts.query.trim()) queries.push(opts.query.trim());
        if (opts.media) {
            if (opts.media.romajiTitle && !queries.includes(opts.media.romajiTitle.trim())) {
                queries.push(opts.media.romajiTitle.trim());
            }
            if (opts.media.englishTitle && !queries.includes(opts.media.englishTitle.trim())) {
                queries.push(opts.media.englishTitle.trim());
            }
        }

        const results: SearchResult[] = [];
        const seen = new Set<string>();

        for (const q of queries) {
            const url = `${this.baseUrl}/buscar/${encodeURIComponent(q)}/`;
            try {
                const res = await fetch(url, {
                    headers: { "User-Agent": this.userAgent }
                });
                if (!res.ok) continue;

                const html = await res.text();
                const pattern = /class="anime__item__text"[\s\S]*?<a\s+href="([^"]+)"[^>]*>([\s\S]*?)<\/a>/g;
                let match: RegExpExecArray | null;

                while ((match = pattern.exec(html)) !== null) {
                    const href = match[1].trim();
                    const title = match[2].replace(/<[^>]+>/g, "").trim();
                    const id = this._cleanId(href);
                    if (!id || !title || seen.has(id)) continue;
                    seen.add(id);
                    results.push({ id, title, url: `${this.baseUrl}/${id}/`, subOrDub: "sub" });
                }
            } catch (e) {
                // Ignore search error
            }
            if (results.length > 0) break;
        }

        return results;
    }

    async findEpisodes(id: string): Promise<EpisodeDetails[]> {
        const url = `${this.baseUrl}/${id}/`;
        const res = await fetch(url, {
            headers: { "User-Agent": this.userAgent }
        });
        if (!res.ok) return [];

        const html = await res.text();
        const episodes: EpisodeDetails[] = [];
        const seen = new Set<number>();

        const addEp = (number: number, epId?: string, title?: string) => {
            if (!number || number <= 0 || seen.has(number)) return;
            seen.add(number);
            episodes.push({
                id: epId ?? `${id}/${number}`,
                number,
                url: `${this.baseUrl}/${id}/${number}/`,
                title: title ?? `Episodio ${number}`,
            });
        };

        // 1. AJAX pagination
        const seriesIdMatch = html.match(/ajax\/pagination_episodes\/(\d+)\//);
        if (seriesIdMatch) {
            const seriesId = seriesIdMatch[1];
            const totalMatch =
                html.match(/num_episodios\s*=\s*(\d+)/) ??
                html.match(/Episodios:<\/span>[^<]*?(\d+)/) ??
                html.match(/data-episodes="(\d+)"/) ??
                html.match(/num-episodios[^>]*>\s*(\d+)/) ??
                html.match(/(\d+)\s*ep[ií]sodios?/i);

            const total = totalMatch ? parseInt(totalMatch[1], 10) : 0;
            const pageCount = total > 0 ? Math.ceil(total / 10) : 1;

            const pageRequests = Array.from({ length: pageCount }, (_, i) =>
                fetch(`${this.baseUrl}/ajax/pagination_episodes/${seriesId}/${i + 1}/`, {
                    headers: {
                        "X-Requested-With": "XMLHttpRequest",
                        "Referer": url,
                        "User-Agent": this.userAgent,
                    },
                }).then(r => r.ok ? r.json() : []).catch(() => [])
            );

            const pages = await Promise.all(pageRequests);
            for (const page of pages) {
                if (!Array.isArray(page)) continue;
                for (const ep of page) {
                    const number = parseInt(ep.number ?? ep.num ?? "0", 10);
                    addEp(number, `${id}/${number}`, ep.title);
                }
            }
        }

        // 2. HTML href scraping
        const escapedId = id.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
        const epPattern = new RegExp(`href="(?:${this.baseUrl})?\\/(${escapedId}\\/(\d+))\\/?"`, "g");
        let match: RegExpExecArray | null;
        while ((match = epPattern.exec(html)) !== null) {
            addEp(parseInt(match[2], 10), match[1]);
        }

        // 3. Synthetic fill if needed
        if (episodes.length === 0) {
            const totalMatch =
                html.match(/num_episodios\s*=\s*(\d+)/) ??
                html.match(/Episodios:<\/span>[^<]*?(\d+)/) ??
                html.match(/data-episodes="(\d+)"/) ??
                html.match(/num-episodios[^>]*>\s*(\d+)/) ??
                html.match(/(\d+)\s*ep[ií]sodios?/i);
            const total = totalMatch ? parseInt(totalMatch[1], 10) : 0;
            for (let i = 1; i <= total; i++) {
                addEp(i);
            }
        }

        // Gap fill
        const maxEp = episodes.reduce((m, e) => Math.max(m, e.number), 0);
        for (let i = 1; i < maxEp; i++) {
            addEp(i);
        }

        return episodes.sort((a, b) => a.number - b.number);
    }

    private async _extractJkPlayer(playerUrl: string): Promise<VideoSource | null> {
        try {
            const res = await fetch(playerUrl, {
                headers: {
                    "Referer": "https://jkanime.net/",
                    "User-Agent": this.userAgent,
                }
            });
            if (!res.ok) return null;
            const html = await res.text();

            const srcMatch = html.match(/<source\s+src=['"](https?:\/\/[^'"]+\.m3u8[^'"]*)['"]/i);
            if (srcMatch) {
                return { url: srcMatch[1], type: "m3u8", quality: "1080p", subtitles: [] };
            }

            const m3u8Match = html.match(/(https?:\/\/[^\s"'<>]+\.m3u8[^\s"'<>]*)/i);
            if (m3u8Match) {
                return { url: m3u8Match[1], type: "m3u8", quality: "1080p", subtitles: [] };
            }
        } catch (e) {
            // Ignore
        }
        return null;
    }

    private async _extractStreamWish(embedUrl: string): Promise<VideoSource | null> {
        try {
            const res = await fetch(embedUrl, {
                headers: {
                    "Referer": "https://jkanime.net/",
                    "User-Agent": this.userAgent,
                }
            });
            if (!res.ok) return null;
            const html = await res.text();

            const unpacked = this._unpackJs(html) || html;
            const m3u8Match = unpacked.match(/(https?:\/\/[^\s"'<>]+\.m3u8[^\s"'<>]*)/i);
            if (m3u8Match) {
                return { url: m3u8Match[1], type: "m3u8", quality: "auto", subtitles: [] };
            }
        } catch (e) {
            // Ignore
        }
        return null;
    }

    private async _extractVidhide(embedUrl: string): Promise<VideoSource | null> {
        try {
            const res = await fetch(embedUrl, {
                headers: {
                    "Referer": "https://jkanime.net/",
                    "User-Agent": this.userAgent,
                }
            });
            if (!res.ok) return null;
            const html = await res.text();

            const unpacked = this._unpackJs(html) || html;
            const m3u8Match = unpacked.match(/(https?:\/\/[^\s"'<>]+\.m3u8[^\s"'<>]*)/i);
            if (m3u8Match) {
                return { url: m3u8Match[1], type: "m3u8", quality: "auto", subtitles: [] };
            }
        } catch (e) {
            // Ignore
        }
        return null;
    }

    private async _extractMp4Upload(embedUrl: string): Promise<VideoSource | null> {
        try {
            const res = await fetch(embedUrl, {
                headers: {
                    "Referer": "https://jkanime.net/",
                    "User-Agent": this.userAgent,
                }
            });
            if (!res.ok) return null;
            const html = await res.text();

            const srcMatch = html.match(/src:\s*"([^"]+\.mp4[^"]*)"/i);
            if (srcMatch) {
                return { url: srcMatch[1], type: "mp4", quality: "auto", subtitles: [] };
            }

            const unpacked = this._unpackJs(html) || html;
            const mp4Match = unpacked.match(/(https?:\/\/[^\s"'<>]+\.mp4[^\s"'<>]*)/i);
            if (mp4Match) {
                return { url: mp4Match[1], type: "mp4", quality: "auto", subtitles: [] };
            }
        } catch (e) {
            // Ignore
        }
        return null;
    }

    private async _extractYourUpload(embedUrl: string): Promise<VideoSource | null> {
        try {
            const res = await fetch(embedUrl, {
                headers: {
                    "Referer": "https://jkanime.net/",
                    "User-Agent": this.userAgent,
                }
            });
            if (!res.ok) return null;
            const html = await res.text();

            const match = html.match(/file:\s*'([^']+\.mp4[^']*)'/i) || html.match(/property="og:video"\s+content="([^"]+)"/i);
            if (match) {
                return { url: match[1], type: "mp4", quality: "auto", subtitles: [] };
            }
        } catch (e) {
            // Ignore
        }
        return null;
    }

    private async _extractVoe(embedUrl: string): Promise<VideoSource | null> {
        try {
            let res = await fetch(embedUrl, {
                headers: { "User-Agent": this.userAgent }
            });
            if (!res.ok) return null;
            let html = await res.text();

            const hop = html.match(/window\.location\.href\s*=\s*'([^']+)'/);
            if (hop && !html.includes("application/json")) {
                res = await fetch(hop[1], {
                    headers: {
                        "Referer": "https://voe.sx/",
                        "User-Agent": this.userAgent,
                    }
                });
                if (res.ok) {
                    html = await res.text();
                }
            }

            const sourcesMatch = html.match(/var\s+sources\s*=\s*\{[^\}]*"hls"\s*:\s*"([^"]+)"/);
            if (sourcesMatch) {
                return { url: sourcesMatch[1], type: "m3u8", quality: "auto", subtitles: [] };
            }

            const sourceMatch = html.match(/var\s+source\s*=\s*'([^']+)'/);
            if (sourceMatch && !sourceMatch[1].includes("test-videos.co.uk")) {
                return { url: sourceMatch[1], type: "mp4", quality: "auto", subtitles: [] };
            }
        } catch (e) {
            // Ignore
        }
        return null;
    }

    async findEpisodeServer(episode: EpisodeDetails, requestedServer: string): Promise<EpisodeServer> {
        const epUrl = episode.url || `${this.baseUrl}/${episode.id}/`;
        const res = await fetch(epUrl, {
            headers: { "User-Agent": this.userAgent }
        });
        if (!res.ok) {
            return { server: requestedServer, headers: {}, videoSources: [] };
        }

        const html = await res.text();
        const serverEmbeds: Record<string, string> = {};

        // 1. Native JK player embeds
        const umMatch = html.match(/https?:\/\/jkanime\.net\/jkplayer\/(?:um|umv)\?[^"\s<>]+/i);
        if (umMatch) {
            serverEmbeds["JK"] = umMatch[0];
        } else {
            const umRel = html.match(/\/(?:jkplayer\/(?:um|umv)\?[^"\s<>]+)/i);
            if (umRel) {
                serverEmbeds["JK"] = `${this.baseUrl}${umRel[0]}`;
            }
        }

        // 2. Parse var servers = [...]
        const serversMatch = html.match(/var\s+servers\s*=\s*(\[[\s\S]*?\]);/);
        if (serversMatch) {
            try {
                const list = JSON.parse(serversMatch[1]);
                for (const item of list) {
                    if (item && item.server && item.remote) {
                        const decoded = this._b64Decode(item.remote);
                        if (decoded) {
                            const key = this._normalizeServerName(item.server);
                            if (!serverEmbeds[key]) {
                                serverEmbeds[key] = decoded;
                            }
                        }
                    }
                }
            } catch (e) {
                // Ignore parse error
            }
        }

        // 3. Fallback iframe parsing
        const iframePattern = /<iframe[^>]+src="([^"]+)"/gi;
        let ifrMatch: RegExpExecArray | null;
        while ((ifrMatch = iframePattern.exec(html)) !== null) {
            const src = ifrMatch[1];
            const key = this._detectServerFromUrl(src);
            if (key && !serverEmbeds[key]) {
                serverEmbeds[key] = src;
            }
        }

        const resolve = async (name: string, url: string): Promise<VideoSource | null> => {
            const norm = name.toUpperCase();
            if (norm === "JK") return await this._extractJkPlayer(url);
            if (norm === "STREAMWISH") return await this._extractStreamWish(url);
            if (norm === "VIDHIDE") return await this._extractVidhide(url);
            if (norm === "MP4UPLOAD") return await this._extractMp4Upload(url);
            if (norm === "YOURUPLOAD") return await this._extractYourUpload(url);
            if (norm === "VOE") return await this._extractVoe(url);
            return null;
        };

        const getHeaders = (name: string, embedUrl: string): Record<string, string> => {
            const norm = name.toUpperCase();
            if (norm === "JK") {
                return { "Referer": "https://jkanime.net/", "Origin": "https://jkanime.net" };
            }
            if (norm === "MP4UPLOAD") {
                return { "Referer": "https://www.mp4upload.com/" };
            }
            if (norm === "YOURUPLOAD") {
                return { "Referer": "https://www.yourupload.com/" };
            }
            return { "Referer": embedUrl || "https://jkanime.net/" };
        };

        const priority = ["JK", "StreamWish", "Vidhide", "Mp4upload", "YourUpload", "Voe"];
        const targetKey = this._normalizeServerName(requestedServer);

        // Try requested server first
        if (serverEmbeds[targetKey]) {
            const source = await resolve(targetKey, serverEmbeds[targetKey]);
            if (source) {
                return {
                    server: requestedServer,
                    headers: getHeaders(targetKey, serverEmbeds[targetKey]),
                    videoSources: [source]
                };
            }
        }

        // Multi-server fallback cascade
        for (const sName of priority) {
            if (sName === targetKey) continue;
            if (serverEmbeds[sName]) {
                const source = await resolve(sName, serverEmbeds[sName]);
                if (source) {
                    return {
                        server: sName,
                        headers: getHeaders(sName, serverEmbeds[sName]),
                        videoSources: [source]
                    };
                }
            }
        }

        // Try any remaining server
        for (const [sName, embedUrl] of Object.entries(serverEmbeds)) {
            const source = await resolve(sName, embedUrl);
            if (source) {
                return {
                    server: sName,
                    headers: getHeaders(sName, embedUrl),
                    videoSources: [source]
                };
            }
        }

        return { server: requestedServer, headers: {}, videoSources: [] };
    }
}