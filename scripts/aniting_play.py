#!/usr/bin/env python3
"""
Aniting Play CLI - Terminal Anime Player with AniList & Video Extractors
Integrated with:
  - Kawaii Animes local replicated catalog (Subtitulado, Audio Latino, Audio Castellano)
  - JKAnime (Native 1080p HLS, StreamWish, Vidhide, Mp4upload, YourUpload, Voe)
  - TioAnime (YourUpload, Voe)
  - Direct video playback in MPV with proper HTTP headers
"""

import sys
import os
import re
import json
import base64
import sqlite3
import urllib.request
import urllib.parse
import subprocess
from concurrent.futures import ThreadPoolExecutor

UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
DB_PATH = os.path.expanduser("~/.cache/aniting/kawaii.db")

class Colors:
    CYAN = '\033[96m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    BLUE = '\033[94m'
    MAGENTA = '\033[95m'
    BOLD = '\033[1m'
    RESET = '\033[0m'

def fetch_url(url, headers=None, data=None, timeout=12):
    hdrs = {'User-Agent': UA}
    if headers:
        hdrs.update(headers)
    req = urllib.request.Request(url, headers=hdrs, data=data)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.read().decode('utf-8', errors='ignore')
    except Exception:
        return None

# ==========================================
# 1. AniList API
# ==========================================

def get_anilist_media(media_id=None, search=None):
    query = """
    query ($id: Int, $search: String) {
      Media(id: $id, search: $search, type: ANIME) {
        id
        title {
          romaji
          english
          native
        }
        synonyms
        episodes
        status
        format
        genres
        description
        coverImage {
          large
        }
      }
    }
    """
    vars_dict = {}
    if media_id:
        vars_dict["id"] = int(media_id)
    elif search:
        vars_dict["search"] = search

    payload = json.dumps({"query": query, "variables": vars_dict}).encode('utf-8')
    raw = fetch_url("https://graphql.anilist.co", headers={"Content-Type": "application/json", "Accept": "application/json"}, data=payload)
    if not raw:
        return None
    try:
        data = json.loads(raw)
        return data.get("data", {}).get("Media")
    except Exception:
        return None

def search_anilist(query_str):
    query = """
    query ($search: String) {
      Page(page: 1, perPage: 5) {
        media(search: $search, type: ANIME) {
          id
          title {
            romaji
            english
          }
          synonyms
          episodes
          format
          status
        }
      }
    }
    """
    payload = json.dumps({"query": query, "variables": {"search": query_str}}).encode('utf-8')
    raw = fetch_url("https://graphql.anilist.co", headers={"Content-Type": "application/json", "Accept": "application/json"}, data=payload)
    if not raw:
        return []
    try:
        data = json.loads(raw)
        return data.get("data", {}).get("Page", {}).get("media", [])
    except Exception:
        return []

# ==========================================
# 2. Extractors (from Kawaii Animes)
# ==========================================

def unpack_dean_edwards(html):
    match = re.search(r'eval\(function\(p,a,c,k,e,[rd].*?split\(\'\|\'\)\)\)', html, re.DOTALL)
    if not match:
        return None
    packed = match.group(0)
    m = re.search(r'\}\s*\(\'([\s\S]*?)\',\s*(\d+),\s*(\d+),\s*\'([\s\S]*?)\'\.split\(\'\|\'\)', packed)
    if not m:
        return None
    p, a, c, k = m.group(1), int(m.group(2)), int(m.group(3)), m.group(4).split('|')

    alphabet = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    def decode_radix(w, base):
        if base <= 36:
            try: return int(w, base)
            except: return -1
        res = 0
        for ch in w:
            idx = alphabet.find(ch)
            if idx == -1 or idx >= base: return -1
            res = res * base + idx
        return res

    def replace_fn(match_obj):
        word = match_obj.group(0)
        idx = decode_radix(word, a)
        if 0 <= idx < len(k) and k[idx]:
            return k[idx]
        return word

    return re.sub(r'\b\w+\b', replace_fn, p)

def extract_streamwish(embed_url):
    html = fetch_url(embed_url, headers={"Referer": "https://jkanime.net/"})
    if not html: return None
    unpacked = unpack_dean_edwards(html) or html
    m = re.search(r'https?://[^\s"\'<>]+\.m3u8[^\s"\'<>]*', unpacked)
    return m.group(0) if m else None

def extract_vidhide(embed_url):
    html = fetch_url(embed_url, headers={"Referer": "https://jkanime.net/"})
    if not html: return None
    unpacked = unpack_dean_edwards(html) or html
    m = re.search(r'https?://[^\s"\'<>]+\.m3u8[^\s"\'<>]*', unpacked)
    return m.group(0) if m else None

def extract_mp4upload(embed_url):
    html = fetch_url(embed_url, headers={"Referer": "https://jkanime.net/"})
    if not html: return None
    m = re.search(r'src:\s*\"([^\"]+\.mp4[^\"]*)\"', html)
    if m: return m.group(0)
    m2 = re.search(r'https?://[^\s"\'<>]+\.mp4[^\s"\'<>]*', html)
    return m2.group(0) if m2 else None

def extract_yourupload(embed_url):
    html = fetch_url(embed_url, headers={"Referer": "https://tioanime.com/"})
    if not html: return None
    m = re.search(r'file:\s*\'([^\']+\.mp4[^\']*)\'', html)
    if m: return m.group(1)
    m2 = re.search(r'property="og:video"\s+content="([^"]+)"', html)
    return m2.group(1) if m2 else None

def extract_jkplayer(player_url):
    html = fetch_url(player_url, headers={"Referer": "https://jkanime.net/"})
    if not html: return None
    src_match = re.search(r'<source\s+src=[\'"](https?://[^\'"]+\.m3u8[^\'"]*)[\'"]', html)
    if src_match: return src_match.group(1)
    m = re.search(r'https?://[^\s"\'<>]+\.m3u8[^\s"\'<>]*', html)
    return m.group(0) if m else None

def extract_luluvdoo(embed_url):
    html = fetch_url(embed_url, headers={"User-Agent": UA})
    if not html: return None
    unpacked = unpack_dean_edwards(html) or html
    m = re.search(r'https?://[^\s"\'<>]+\.m3u8[^\s"\'<>]*', unpacked)
    return m.group(0) if m else None

# ==========================================
# 3. Kawaii Animes Sync & Resolution
# ==========================================

def ensure_kawaii_db():
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    if os.path.exists(DB_PATH) and os.path.getsize(DB_PATH) > 1024 * 1024:
        return

    print(f"\n{Colors.YELLOW}{Colors.BOLD}⚡ Sincronizando catálogo de Kawaii Animes en local...{Colors.RESET}")
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute('CREATE TABLE IF NOT EXISTS anime (id INT PRIMARY KEY, title TEXT, alt TEXT)')
    c.execute('CREATE TABLE IF NOT EXISTS episode (id INT PRIMARY KEY, num INT, aid INT)')
    c.execute('CREATE TABLE IF NOT EXISTS player (id INT PRIMARY KEY, link TEXT, lang TEXT, sid INT, eid INT)')
    c.execute('CREATE INDEX IF NOT EXISTS idx_ep_aid ON episode(aid)')
    c.execute('CREATE INDEX IF NOT EXISTS idx_pl_eid ON player(eid)')

    # 1. Anime
    print("  - Descargando animes...")
    r = fetch_url('https://api.kawaiianimes.app/api/v4/bulk-sync?target=anime&last_id=0&limit=5000', data=b'')
    if r:
        animes = json.loads(r).get('a', [])
        c.executemany('INSERT OR REPLACE INTO anime VALUES (?, ?, ?)', [(a['id'], a['n'], a.get('na', '')) for a in animes])
        conn.commit()

    # 2. Episodes
    print("  - Descargando episodios...")
    def fetch_ep(last_id):
        raw = fetch_url(f'https://api.kawaiianimes.app/api/v4/bulk-sync?target=episode&last_id={last_id}&limit=5000', data=b'')
        return json.loads(raw).get('e', []) if raw else []

    with ThreadPoolExecutor(max_workers=8) as ex:
        chunks = list(ex.map(fetch_ep, range(0, 40000, 5000)))
    all_eps = [e for ch in chunks for e in ch]
    c.executemany('INSERT OR REPLACE INTO episode VALUES (?, ?, ?)', [(e['id'], e['n'], e['aid']) for e in all_eps])
    conn.commit()

    # 3. Players
    print("  - Descargando reproductores (Sub, Latino, Castellano)...")
    def fetch_pl(last_id):
        raw = fetch_url(f'https://api.kawaiianimes.app/api/v4/bulk-sync?target=player&last_id={last_id}&limit=5000', data=b'')
        return json.loads(raw).get('p', []) if raw else []

    with ThreadPoolExecutor(max_workers=8) as ex:
        pl_chunks = list(ex.map(fetch_pl, range(0, 180000, 5000)))
    all_pl = [p for ch in pl_chunks for p in ch]
    c.executemany('INSERT OR REPLACE INTO player VALUES (?, ?, ?, ?, ?)', [(p['id'], p['lk'], p['lg'], p['sid'], p['eid']) for p in all_pl])
    conn.commit()
    conn.close()
    print(f"{Colors.GREEN}✓ ¡Base de datos de Kawaii Animes sincronizada con éxito!{Colors.RESET}\n")

def resolve_kawaii_animes(query_names, ep_num):
    if not os.path.exists(DB_PATH):
        return []

    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()

    aid = None
    for name in query_names:
        clean = name.strip().lower()
        if len(clean) < 3: continue
        c.execute('SELECT id FROM anime WHERE LOWER(title) LIKE ? OR LOWER(alt) LIKE ? LIMIT 1', (f'%{clean}%', f'%{clean}%'))
        row = c.fetchone()
        if row:
            aid = row[0]
            break

    if not aid:
        conn.close()
        return []

    # Get episode ID
    c.execute('SELECT id FROM episode WHERE aid = ? AND num = ? LIMIT 1', (aid, ep_num))
    ep_row = c.fetchone()
    if not ep_row:
        conn.close()
        return []
    eid = ep_row[0]

    # Get players
    c.execute('SELECT link, lang, sid FROM player WHERE eid = ?', (eid,))
    players = c.fetchall()
    conn.close()

    lang_labels = {'0': 'Subtitulado', '1': 'Audio Latino', '2': 'Audio Castellano'}
    server_names = {1: 'VOE (Gamma)', 2: 'Filemoon (Delta)', 3: 'LuluStream (Epsilon)', 4: 'StreamWish (Alpha)'}
    hosts = {1: 'https://teresapoliticallearn.com', 2: 'https://byseraguci.com', 3: 'https://luluvdoo.com', 4: 'https://masukestin.com'}

    def resolve_one(pl):
        link, lang, sid = pl
        rev = link[::-1]
        host = hosts.get(sid, '')
        if not host: return None
        embed_url = f"{host}/e/{rev}"
        lang_str = lang_labels.get(lang, 'Sub')
        srv_str = server_names.get(sid, f'Server {sid}')

        if sid == 3: # LuluStream
            m3u8 = extract_luluvdoo(embed_url)
            if m3u8:
                return {
                    "provider": "Kawaii Animes",
                    "server": f"LuluStream [{lang_str}]",
                    "type": "m3u8",
                    "url": m3u8,
                    "headers": {"Referer": embed_url, "User-Agent": UA}
                }
        elif sid == 4: # StreamWish
            m3u8 = extract_streamwish(embed_url)
            if m3u8:
                return {
                    "provider": "Kawaii Animes",
                    "server": f"StreamWish [{lang_str}]",
                    "type": "m3u8",
                    "url": m3u8,
                    "headers": {"Referer": embed_url, "User-Agent": UA}
                }
        return None

    results = []
    with ThreadPoolExecutor(max_workers=6) as ex:
        for res in ex.map(resolve_one, players):
            if res:
                results.append(res)

    return results

# ==========================================
# 4. Other Provider Resolvers (JKAnime, TioAnime)
# ==========================================

def resolve_jkanime(query_names, ep_num):
    base = "https://jkanime.net"
    anime_slug = None
    for name in query_names:
        url = f"{base}/buscar/{urllib.parse.quote(name)}/"
        html = fetch_url(url)
        if not html: continue
        matches = re.findall(r'class="anime__item__text"[\s\S]*?<a\s+href="([^"]+)"[^>]*>([\s\S]*?)</a>', html)
        if matches:
            href = matches[0][0].replace(base, '').strip('/')
            anime_slug = href
            break

    if not anime_slug:
        return []

    ep_url = f"{base}/{anime_slug}/{ep_num}/"
    ep_html = fetch_url(ep_url)
    if not ep_html:
        return []

    results = []
    # 1. Native JK
    um_match = re.search(r'https?://jkanime\.net/jkplayer/(?:um|umv)\?[^"\'\s<>]+', ep_html)
    if um_match:
        m3u8 = extract_jkplayer(um_match.group(0))
        if m3u8:
            results.append({
                "provider": "JKAnime",
                "server": "JK Native 1080p (Sub)",
                "type": "m3u8",
                "url": m3u8,
                "headers": {"Referer": "https://jkanime.net/", "Origin": "https://jkanime.net"}
            })

    # 2. Parse var servers
    servers_match = re.search(r'var\s+servers\s*=\s*(\[[\s\S]*?\]);', ep_html)
    if servers_match:
        try:
            servers = json.loads(servers_match.group(1))
            for item in servers:
                s_name = item.get("server", "")
                remote_b64 = item.get("remote", "")
                if not remote_b64: continue
                try:
                    embed_url = base64.b64decode(remote_b64).decode('utf-8', errors='ignore').strip()
                except Exception:
                    continue

                if "streamwish" in s_name.lower():
                    m3u8 = extract_streamwish(embed_url)
                    if m3u8:
                        results.append({
                            "provider": "JKAnime",
                            "server": "StreamWish (Sub)",
                            "type": "m3u8",
                            "url": m3u8,
                            "headers": {"Referer": embed_url}
                        })
                elif "vidhide" in s_name.lower():
                    m3u8 = extract_vidhide(embed_url)
                    if m3u8:
                        results.append({
                            "provider": "JKAnime",
                            "server": "Vidhide (Sub)",
                            "type": "m3u8",
                            "url": m3u8,
                            "headers": {"Referer": embed_url}
                        })
                elif "mp4upload" in s_name.lower():
                    mp4 = extract_mp4upload(embed_url)
                    if mp4:
                        results.append({
                            "provider": "JKAnime",
                            "server": "Mp4upload (Sub)",
                            "type": "mp4",
                            "url": mp4,
                            "headers": {"Referer": "https://www.mp4upload.com/"}
                        })
                elif "yourupload" in s_name.lower():
                    mp4 = extract_yourupload(embed_url)
                    if mp4:
                        results.append({
                            "provider": "JKAnime",
                            "server": "YourUpload (Sub)",
                            "type": "mp4",
                            "url": mp4,
                            "headers": {"Referer": "https://www.yourupload.com/"}
                        })
        except Exception:
            pass

    return results

def resolve_tioanime(query_names, ep_num):
    base = "https://tioanime.com"
    anime_slug = None
    for name in query_names:
        url = f"{base}/directorio?q={urllib.parse.quote(name)}"
        html = fetch_url(url)
        if not html: continue
        matches = re.findall(r'<article\s+class="anime"[\\s\\S]*?<a\s+href="([^"]+)"[\\s\\S]*?<h3\s+class="title">([^<]+)</h3>', html)
        if matches:
            slug = matches[0][0].replace('/anime/', '').strip('/')
            anime_slug = slug
            break

    if not anime_slug:
        return []

    ep_url = f"{base}/ver/{anime_slug}-{ep_num}"
    ep_html = fetch_url(ep_url)
    if not ep_html:
        return []

    results = []
    vids_match = re.search(r'var\s+videos\s*=\s*(\[[\s\S]*?\]);', ep_html)
    if vids_match:
        try:
            videos = json.loads(vids_match.group(1))
            for v in videos:
                s_name = v[0]
                embed_url = v[1]
                if s_name.lower() == "yourupload":
                    mp4 = extract_yourupload(embed_url)
                    if mp4:
                        results.append({
                            "provider": "TioAnime",
                            "server": "YourUpload (Sub)",
                            "type": "mp4",
                            "url": mp4,
                            "headers": {"Referer": "https://www.yourupload.com/"}
                        })
        except Exception:
            pass

    return results

# ==========================================
# 5. AnimeX Resolver (GraphQL AniList ID -> Yuki Multi-Quality 1080p HLS)
# ==========================================

def encode_animex_uwu(url, referer, user_agent=None, proxy_host='https://cdnx.aniwatchtv.site'):
    key = b'10b06cdc1ca48c9fb0b94af97cc040cf'
    payload = url.encode('utf-8') + b'\x00' + referer.encode('utf-8')
    if user_agent:
        payload += b'\x00' + user_agent.encode('utf-8')
    xored = bytearray(payload)
    for i in range(len(xored)):
        xored[i] ^= key[i % len(key)]
    token = base64.urlsafe_b64encode(xored).decode('utf-8').rstrip('=')
    return f'{proxy_host}/uwu/{token}'

def resolve_animex(anilist_id, ep_num):
    results = []
    # 1. Query GraphQL for AnimeX slug
    query = f'query {{ anime(anilistId: {anilist_id}) {{ id episodeCount subCount dubCount }} }}'
    payload = json.dumps({'query': query}).encode('utf-8')
    raw = fetch_url('https://graphql.animex.one/graphql', headers={
        'Content-Type': 'application/json',
        'User-Agent': UA
    }, data=payload)

    if not raw:
        return []

    try:
        data = json.loads(raw)
        anime_data = data.get('data', {}).get('anime')
        if not anime_data:
            return []
        slug = anime_data['id']
        sub_count = anime_data.get('subCount', 0)
        dub_count = anime_data.get('dubCount', 0)
    except Exception:
        return []

    types_to_try = []
    if sub_count >= ep_num or sub_count == 0:
        types_to_try.append(('sub', 'Sub'))
    if dub_count >= ep_num:
        types_to_try.append(('dub', 'Dub'))

    for stream_type, type_label in types_to_try:
        url = f'https://pp.animex.one/rest/api/sources?id={slug}&epNum={ep_num}&type={stream_type}&providerId=yuki'
        raw_sources = fetch_url(url, headers={
            'User-Agent': UA,
            'Referer': 'https://plyr.animex.one/',
            'Origin': 'https://plyr.animex.one'
        })
        if not raw_sources:
            continue
        try:
            resp = json.loads(raw_sources)
            sources = resp.get('sources') or []
            if sources:
                real_m3u8 = sources[0]['url']
                hdrs = resp.get('headers') or {}
                ref = hdrs.get('Referer', 'https://megaplay.buzz')
                ua = hdrs.get('User-Agent')
                proxy_url = encode_animex_uwu(real_m3u8, ref, ua)
                results.append({
                    'provider': 'AnimeX',
                    'server': f'Yuki 1080p ({type_label})',
                    'type': 'm3u8',
                    'url': proxy_url,
                    'extra_mpv_args': ['--demuxer-lavf-format=hls'],
                    'chapters': resp.get('chapters') or []
                })
        except Exception:
            pass

    return results

# ==========================================
# 6. Main CLI Execution
# ==========================================

def play_in_mpv(stream_info, title, ep_num):
    url = stream_info["url"]
    headers = stream_info.get("headers", {})
    mpv_title = f"[Aniting] {title} - Episodio {ep_num} ({stream_info['provider']} - {stream_info['server']})"

    cmd = ["mpv", url, f"--title={mpv_title}"]
    
    if "Referer" in headers:
        cmd.append(f"--referrer={headers['Referer']}")
    if "User-Agent" in headers:
        cmd.append(f"--user-agent={headers['User-Agent']}")

    # Extra arguments (like --demuxer-lavf-format=hls for masked streams)
    if "extra_mpv_args" in stream_info:
        cmd.extend(stream_info["extra_mpv_args"])

    # Any other custom headers
    other_headers = [f"{k}: {v}" for k, v in headers.items() if k not in ("Referer", "User-Agent")]
    if other_headers:
        joined_hdrs = ",".join(other_headers)
        cmd.append(f"--http-header-fields={joined_hdrs}")

    print(f"\n{Colors.GREEN}{Colors.BOLD}▶ Iniciando MPV:{Colors.RESET}")
    print(f"  {Colors.CYAN}Fuente:{Colors.RESET} {stream_info['provider']}")
    print(f"  {Colors.CYAN}Servidor:{Colors.RESET} {stream_info['server']}")
    print(f"  {Colors.CYAN}Stream:{Colors.RESET} {url[:90]}...")

    # Chapters (Intro / Outro skip)
    chapters = stream_info.get("chapters") or []
    for ch in chapters:
        t_start = ch.get("start", 0)
        t_end = ch.get("end", 0)
        if t_end > t_start:
            m_s, s_s = divmod(t_start, 60)
            m_e, s_e = divmod(t_end, 60)
            print(f"  {Colors.YELLOW}⏱ {ch.get('title', 'Segmento')}:{Colors.RESET} {m_s:02d}:{s_s:02d} -> {m_e:02d}:{s_e:02d}")

    print(f"{Colors.YELLOW}Disfruta el capítulo ✨ (Presiona 'q' en MPV para salir){Colors.RESET}\n")

    try:
        subprocess.run(cmd)
    except FileNotFoundError:
        print(f"{Colors.RED}Error: 'mpv' no está instalado en tu sistema.{Colors.RESET}")

def main():
    print(f"\n{Colors.MAGENTA}{Colors.BOLD}╔════════════════════════════════════════════════════════╗{Colors.RESET}")
    print(f"{Colors.MAGENTA}{Colors.BOLD}║      ANITING PLAY - TERMINAL STREAMER (KAWAII + JK)    ║{Colors.RESET}")
    print(f"{Colors.MAGENTA}{Colors.BOLD}╚════════════════════════════════════════════════════════╝{Colors.RESET}")

    ensure_kawaii_db()

    user_input = ""
    if len(sys.argv) > 1:
        user_input = " ".join(sys.argv[1:]).strip()
    else:
        user_input = input(f"{Colors.CYAN}Introduce el ID de AniList o el nombre del anime:{Colors.RESET} ").strip()

    if not user_input:
        print(f"{Colors.RED}No se introdujo ningún anime. Saliendo.{Colors.RESET}")
        return

    media = None
    if user_input.isdigit():
        print(f"{Colors.YELLOW}Buscando AniList ID {user_input}...{Colors.RESET}")
        media = get_anilist_media(media_id=int(user_input))
    else:
        print(f"{Colors.YELLOW}Buscando '{user_input}' en AniList...{Colors.RESET}")
        candidates = search_anilist(user_input)
        if not candidates:
            print(f"{Colors.RED}No se encontraron resultados en AniList.{Colors.RESET}")
            return
        if len(candidates) == 1:
            media = candidates[0]
        else:
            print(f"\n{Colors.GREEN}Resultados encontrados:{Colors.RESET}")
            for idx, c in enumerate(candidates, 1):
                t_romaji = c["title"].get("romaji", "")
                t_eng = c["title"].get("english", "")
                title_disp = t_romaji if not t_eng else f"{t_romaji} ({t_eng})"
                eps = c.get("episodes") or "?"
                print(f"  {Colors.BOLD}[{idx}]{Colors.RESET} {title_disp} [{c.get('format', 'TV')}, {eps} eps] (ID: {c['id']})")

            sel = input(f"\n{Colors.CYAN}Selecciona un anime [1-{len(candidates)}] (default: 1):{Colors.RESET} ").strip()
            sel_idx = int(sel) - 1 if sel.isdigit() and 1 <= int(sel) <= len(candidates) else 0
            media = candidates[sel_idx]

    if not media:
        print(f"{Colors.RED}No se pudo cargar la información del anime.{Colors.RESET}")
        return

    romaji = media["title"].get("romaji", "")
    english = media["title"].get("english", "")
    synonyms = media.get("synonyms") or []
    total_eps = media.get("episodes") or 1
    display_title = romaji or english

    print(f"\n{Colors.GREEN}{Colors.BOLD}✓ Anime seleccionado:{Colors.RESET} {Colors.BOLD}{display_title}{Colors.RESET}")
    print(f"  {Colors.CYAN}AniList ID:{Colors.RESET} {media['id']}")
    print(f"  {Colors.CYAN}Episodios totales:{Colors.RESET} {total_eps}")
    print(f"  {Colors.CYAN}Estado:{Colors.RESET} {media.get('status', 'UNKNOWN')}")

    ep_input = input(f"\n{Colors.CYAN}¿Qué episodio deseas ver? (1-{total_eps}) [default: 1]:{Colors.RESET} ").strip()
    ep_num = int(ep_input) if ep_input.isdigit() and int(ep_input) > 0 else 1

    print(f"\n{Colors.YELLOW}Buscando servidores para el Episodio {ep_num}...{Colors.RESET}")
    query_names = [romaji, english] + synonyms
    query_names = [n for n in query_names if n and len(n.strip()) > 2]

    streams = []

    # 1. AnimeX (Direct AniList ID GraphQL -> Multi-Quality Yuki 1080p Sub & Dub)
    animex_streams = resolve_animex(media["id"], ep_num)
    if animex_streams:
        print(f"  {Colors.GREEN}✓ Encontrados {len(animex_streams)} servidores en AnimeX{Colors.RESET}")
        streams.extend(animex_streams)

    # 2. Kawaii Animes (Local database -> Direct LuluStream with Sub/Latino/Castellano)
    kawaii_streams = resolve_kawaii_animes(query_names, ep_num)
    if kawaii_streams:
        print(f"  {Colors.GREEN}✓ Encontrados {len(kawaii_streams)} servidores en Kawaii Animes{Colors.RESET}")
        streams.extend(kawaii_streams)

    # 3. JKAnime
    jk_streams = resolve_jkanime(query_names, ep_num)
    if jk_streams:
        print(f"  {Colors.GREEN}✓ Encontrados {len(jk_streams)} servidores en JKAnime{Colors.RESET}")
        streams.extend(jk_streams)

    # 4. TioAnime
    tio_streams = resolve_tioanime(query_names, ep_num)
    if tio_streams:
        print(f"  {Colors.GREEN}✓ Encontrados {len(tio_streams)} servidores en TioAnime{Colors.RESET}")
        streams.extend(tio_streams)

    if not streams:
        print(f"{Colors.RED}No se encontraron servidores disponibles para el episodio {ep_num}.{Colors.RESET}")
        return

    print(f"\n{Colors.GREEN}{Colors.BOLD}Opciones de reproducción disponibles:{Colors.RESET}")
    for idx, s in enumerate(streams, 1):
        if s['provider'] == 'AnimeX':
            prov_col = Colors.BLUE
        elif s['provider'] == 'Kawaii Animes':
            prov_col = Colors.MAGENTA
        else:
            prov_col = Colors.CYAN
        print(f"  {Colors.BOLD}[{idx}]{Colors.RESET} {prov_col}{s['provider']}{Colors.RESET} ➜ {s['server']} ({s['type'].upper()})")

    srv_sel = input(f"\n{Colors.CYAN}Selecciona una opción [1-{len(streams)}] (default: 1):{Colors.RESET} ").strip()
    srv_idx = int(srv_sel) - 1 if srv_sel.isdigit() and 1 <= int(srv_sel) <= len(streams) else 0

    chosen_stream = streams[srv_idx]
    play_in_mpv(chosen_stream, display_title, ep_num)

if __name__ == "__main__":
    main()
