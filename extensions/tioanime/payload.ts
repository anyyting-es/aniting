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
    baseUrl = "https://tioanime.com";
    userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";

    getSettings(): Settings {
        return {
            episodeServers: ["YourUpload", "Voe", "Okru", "Mega"],
            supportsDub: false,
        };
    }

    private _cleanSlug(href: string): string {
        return href
            .replace(this.baseUrl, "")
            .replace(/^\/+/, "")
            .replace(/\/+$/, "")
            .replace(/^anime\//, "")
            .replace(/^ver\//, "");
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
            if (Array.isArray(opts.media.synonyms)) {
                for (const s of opts.media.synonyms) {
                    if (s && s.trim() && !queries.includes(s.trim())) {
                        queries.push(s.trim());
                    }
                }
            }
        }

        const results: SearchResult[] = [];
        const seen = new Set<string>();

        for (const q of queries) {
            const url = `${this.baseUrl}/directorio?q=${encodeURIComponent(q)}`;
            try {
                const res = await fetch(url, {
                    headers: { "User-Agent": this.userAgent }
                });
                if (!res.ok) continue;

                const html = await res.text();
                // Scrape anime card links
                const pattern = /<article\s+class="anime"[\s\S]*?<a\s+href="([^"]+)"[\s\S]*?<h3\s+class="title">([^<]+)<\/h3>/gi;
                let match: RegExpExecArray | null;

                while ((match = pattern.exec(html)) !== null) {
                    const href = match[1].trim();
                    const title = match[2].trim();
                    const slug = this._cleanSlug(href);
                    if (!slug || !title || seen.has(slug)) continue;
                    seen.add(slug);
                    results.push({
                        id: slug,
                        title,
                        url: `${this.baseUrl}/anime/${slug}`,
                        subOrDub: "sub"
                    });
                }
            } catch (e) {
                // Ignore search error
            }
            if (results.length > 0) break;
        }

        return results;
    }

    async findEpisodes(id: string): Promise<EpisodeDetails[]> {
        const slug = this._cleanSlug(id);
        const url = `${this.baseUrl}/anime/${slug}`;
        const res = await fetch(url, {
            headers: { "User-Agent": this.userAgent }
        });
        if (!res.ok) return [];

        const html = await res.text();
        const epsMatch = html.match(/var\s+episodes\s*=\s*(\[[\s\S]*?\]);/);
        if (!epsMatch) return [];

        try {
            const rawList: number[] = JSON.parse(epsMatch[1]);
            const episodes: EpisodeDetails[] = [];
            // rawList is usually sorted descending [12, 11, 10, ...]
            const sorted = [...rawList].sort((a, b) => a - b);
            for (const num of sorted) {
                episodes.push({
                    id: `${slug}-${num}`,
                    number: num,
                    url: `${this.baseUrl}/ver/${slug}-${num}`,
                    title: `Episodio ${num}`,
                });
            }
            return episodes;
        } catch (e) {
            console.error("Error parsing TioAnime episodes:", e);
            return [];
        }
    }

    private async _extractYourUpload(embedUrl: string): Promise<VideoSource | null> {
        try {
            const res = await fetch(embedUrl, {
                headers: {
                    "Referer": "https://tioanime.com/",
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
        const epUrl = episode.url || `${this.baseUrl}/ver/${episode.id}`;
        const res = await fetch(epUrl, {
            headers: { "User-Agent": this.userAgent }
        });
        if (!res.ok) {
            return { server: requestedServer, headers: {}, videoSources: [] };
        }

        const html = await res.text();
        const vidsMatch = html.match(/var\s+videos\s*=\s*(\[[\s\S]*?\]);/);
        if (!vidsMatch) {
            return { server: requestedServer, headers: {}, videoSources: [] };
        }

        const serverEmbeds: Record<string, string> = {};
        try {
            const list: [string, string][] = JSON.parse(vidsMatch[1]);
            for (const item of list) {
                if (item && item[0] && item[1]) {
                    serverEmbeds[item[0].trim()] = item[1].trim();
                }
            }
        } catch (e) {
            console.error("Error parsing TioAnime videos:", e);
        }

        const resolve = async (name: string, url: string): Promise<VideoSource | null> => {
            const norm = name.toUpperCase();
            if (norm.includes("YOURUPLOAD")) return await this._extractYourUpload(url);
            if (norm.includes("VOE")) return await this._extractVoe(url);
            return null;
        };

        const getHeaders = (name: string, embedUrl: string): Record<string, string> => {
            const norm = name.toUpperCase();
            if (norm.includes("YOURUPLOAD")) {
                return { "Referer": "https://www.yourupload.com/" };
            }
            return { "Referer": embedUrl || "https://tioanime.com/" };
        };

        // Try requested server first
        for (const [sName, embedUrl] of Object.entries(serverEmbeds)) {
            if (sName.toLowerCase() === requestedServer.toLowerCase()) {
                const source = await resolve(sName, embedUrl);
                if (source) {
                    return {
                        server: sName,
                        headers: getHeaders(sName, embedUrl),
                        videoSources: [source]
                    };
                }
            }
        }

        // Fallback cascade: try any working server (YourUpload, Voe)
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