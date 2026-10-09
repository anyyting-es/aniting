# Video Extractors & Streaming Architecture (VIDEOS.md)

Este documento detalla la ingeniería inversa, endpoints, protocolos de cifrado y mecanismos de resolución de video implementados en la suite **Aniting** y en la herramienta de línea de comandos **`aniting-play`**.

---

## 1. Resumen de Proveedores Integrados

| Proveedor | Enfoque / Fuente | Audios / Calidades | Tipo de Extracción | Estado en CLI |
| :--- | :--- | :--- | :--- | :---: |
| **AnimeX** (`animex.one`) | Agregador (AllAnime + HiAnime + DramaHot) | Subtitulado (1080p) + Doblaje en inglés | GraphQL + REST + Proxy XOR `/uwu/` | ✅ Activo |
| **Kawaii Animes** | Base de datos SQLite replicada (`bulk-sync`) | **Subtitulado**, **Audio Latino**, **Audio Castellano** (1080p) | SQLite local + Unpack Dean Edwards | ✅ Activo |
| **JKAnime** (`jkanime.net`) | Scraper HTML en tiempo real | Subtitulado (1080p) | Scraper Regex + Unpackers HLS/MP4 | ✅ Activo |
| **TioAnime** (`tioanime.com`) | Scraper HTML en tiempo real | Subtitulado (720p/1080p) | Scraper Regex (YourUpload, etc.) | ✅ Activo |

---

## 2. AnimeX (`https://animex.one`)

### Arquitectura Técnica
- **Stack**: SvelteKit en el frontend tras Cloudflare.
- **Identificadores**: Compatible nativamente con **AniList ID**. No requiere coincidencias difusas de títulos.

### Endpoints y Protocolo de Resolución

#### Paso 1: Mapeo de AniList ID a Slug Interno (GraphQL)
Se envía una consulta a su endpoint GraphQL público:
```http
POST https://graphql.animex.one/graphql
Content-Type: application/json

query {
  anime(anilistId: 151807) {
    id
    episodeCount
    subCount
    dubCount
  }
}
```
**Respuesta**:
```json
{
  "data": {
    "anime": {
      "id": "solo-leveling-cgjkx",
      "episodeCount": 12,
      "subCount": 25,
      "dubCount": 25
    }
  }
}
```

#### Paso 2: Obtención de Fuentes y Capítulos (REST)
Se consulta su microservicio interno `pp.animex.one`:
```http
GET https://pp.animex.one/rest/api/sources?id=solo-leveling-cgjkx&epNum=1&type=sub&providerId=yuki
Referer: https://plyr.animex.one/
Origin: https://plyr.animex.one
```

**Respuesta**:
```json
{
  "sources": [
    {
      "url": "https://fetch.nexabloom.top/anime/.../master.m3u8?token=...",
      "quality": "auto",
      "type": "application/vnd.apple.mpegurl"
    }
  ],
  "chapters": [
    { "title": "Intro", "start": 76, "end": 101 },
    { "title": "Outro", "start": 1325, "end": 1414 }
  ],
  "headers": {}
}
```

#### Paso 3: Descifrado del Gateway Proxy `/uwu/` (XOR Cipher)
El reproductor oficial enmascara y rutea el stream `yuki` (AllAnime) a través de `https://cdnx.aniwatchtv.site/uwu/<token>` para evitar bloqueos de CORS e inspecciones de red.
- **Clave XOR estática**: `10b06cdc1ca48c9fb0b94af97cc040cf`
- **Algoritmo**:
  1. Empaquetar: `bytes(url) + b"\x00" + bytes(referer)` (y opcionalmente `+ b"\x00" + bytes(userAgent)` si la API lo exige).
  2. Aplicar operación XOR byte a byte contra la clave de 32 bytes (`payload[i] ^ key[i % 32]`).
  3. Codificar en Base64 URL-safe (sin relleno `=`).
  4. Formar URL: `https://cdnx.aniwatchtv.site/uwu/<token>`.

#### Paso 4: Enmascaramiento MIME (`image/jpeg`)
El gateway entrega el playlist HLS con la cabecera HTTP `Content-Type: image/jpeg` para despistar analizadores de tráfico.
- **Solución en MPV**: Pasar el flag `--demuxer-lavf-format=hls` para forzar la interpretación HLS independientemente del MIME reportado.

---

## 3. Kawaii Animes (`app.kawaiianimes.com`)

### Arquitectura Técnica
- **Stack**: Kotlin / Compose Multiplatform desktop (`composeApp-desktop.jar`).
- **Base de Datos Replicada**:
  - Almacenada en SQLite local: `~/.cache/aniting/kawaii.db` (~7.5 MB).
  - Poblada mediante el endpoint `https://api.kawaiianimes.app/api/v4/bulk-sync?target={anime|episode|player|server}`.
  - Tablas principales:
    - `anime`: `id`, `title`, `alt` (nombres alternativos y sinónimos).
    - `episode`: `id`, `num` (número de capítulo), `aid` (ID del anime).
    - `player`: `id`, `link`, `lang` (idioma), `sid` (servidor), `eid` (episodio).

### Soporte de Idiomas por Capítulo
- `lang = 0`: **Subtitulado** (Audio Japonés, Subtítulos en Español).
- `lang = 1`: **Audio Latino** (Doblaje Latino).
- `lang = 2`: **Audio Castellano** (Doblaje España).

### Servidores y Descifrado de Enlaces
Los enlaces en la base de datos están almacenados en cadena invertida (`link[::-1]`).
1. **LuluStream / Epsilon (`sid = 3`)**:
   - Host: `https://luluvdoo.com/e/<reversed_link>`
   - Extracción: El HTML embebido contiene un script comprimido con **Dean Edwards Packer** (`eval(function(p,a,c,k,e,d)...)`).
   - Desempaquetado: Se extrae la expresión regular `https?://[^\s"'<>]+\.m3u8` obteniendo el archivo HLS Master directo en **1080p nativo**.
   - Cabeceras requeridas: Requiere `--referrer=https://luluvdoo.com/e/<link>` y `--user-agent=<UA>`.
2. **Filemoon / Delta (`sid = 2`)**:
   - Host: `https://byseraguci.com/e/<reversed_link>`
   - API interna: `/api/videos/<code_reversed>` que retorna un payload cifrado con **AES-256-GCM** y llaves rotativas (`key_parts`).

---

## 4. JKAnime (`https://jkanime.net`)

### Arquitectura Técnica
- Scraper web HTML sobre las URLs del anime y capítulos: `https://jkanime.net/{slug}/{ep_num}/`.

### Servidores Extraídos
1. **JK Native Player (1080p)**:
   - Extraído de `https://jkanime.net/jk.php?u=...`
   - Obtiene el `.m3u8` master con cabecera `Referer: https://jkanime.net/`.
2. **StreamWish (`awish.pro` / `streamwish.to`)**:
   - Desempaquetado con Dean Edwards Packer para obtener el stream `.m3u8`.
3. **Vidhide (`vidhidepre.com`)**:
   - Desempaquetado JS Dean Edwards hacia `.m3u8`.
4. **Mp4Upload**:
   - Extracción del archivo `.mp4` directo mediante expresión regular sobre `src: "..."`.
5. **YourUpload**:
   - Extracción del archivo `.mp4` directo mediante `file: '...'` u `og:video`.

---

## 5. TioAnime (`https://tioanime.com`)

### Arquitectura Técnica
- Scraper web sobre las URLs de episodios: `https://tioanime.com/ver/{slug}-{ep_num}`.
- En la variable JavaScript incrustada `var videos = [...]` se definen los servidores disponibles.

### Servidores Extraídos
1. **YourUpload**: Extracción directa de MP4 con `Referer: https://www.yourupload.com/`.
2. **VOE / StreamWish**: Redirecciones adicionales a reproductores compatibles.

---

## 6. Uso desde Terminal con `aniting-play`

El script ejecutable se encuentra en `scripts/aniting_play.py` y está enlazado a `~/.local/bin/aniting-play`:

```bash
# Modo interactivo con búsqueda en tiempo real
aniting-play

# Búsqueda directa por AniList ID (ej: Solo Leveling)
aniting-play 151807

# Búsqueda por título
aniting-play "Jujutsu Kaisen"
```

### Características en Reproducción:
* **Concurrencia multihilo**: Consulta AnimeX, Kawaii Animes, JKAnime y TioAnime en paralelo (tiempo de resolución < 0.8s).
* **Saltos de Intro/Outro automáticos**: AnimeX reporta las marcas de tiempo de inicio y fin del Opening y Ending en consola.
* **Separación de cabeceras en MPV**: Utiliza parámetros directos `--referrer` y `--user-agent` para evitar rechazos `400 Bad Request` por comas en las cadenas de User-Agent.
* **Compatibilidad HLS forzada**: Utiliza `--demuxer-lavf-format=hls` para decodificar automáticamente streams enmascarados como imágenes.

---

## 7. Anime Nexus (`https://anime.nexus`) - Investigación Completa

### 7.1. Arquitectura de Infraestructura y Pila Tecnológica
- **Proxy y Protección Perimetral**: Cloudflare WAF con reglas avanzadas de desafío JavaScript, mitigación de scraping y verificación de bots.
- **Frontend**: Desarrollado con **TanStack Start** (framework SSR basado en Vite, Nitro y React 19) consumiendo rutas tipadas en el cliente tras `https://anime.nexus/`.
  - El HTML inicial contiene hidratación de estado (`__TSR_DEHYDRATED__` / scripts de TanStack Router) con metadatos pre-renderizados en el servidor.
- **Backend API**: Servido bajo un subdominio independiente: `https://api.anime.nexus/api/v1/`.
  - Motor: **WinterCMS** (fork moderno y modular de OctoberCMS sobre base Laravel PHP).
  - Estructura desacoplada: El catálogo y metadatos se exponen públicamente en formato JSON REST, mientras que el pipeline de entrega de streams está fuertemente protegido.

---

### 7.2. Endpoints Públicos del Catálogo (Sin Bloqueo Anti-Bot)
Las consultas de catálogo, fichas informativas y listados de episodios no requieren resolución de desafíos anti-bot y responden directamente con JSON:

#### 1. Búsqueda y Autocompletado
```http
GET https://api.anime.nexus/api/v1/anime/search?query=Solo+Leveling
Accept: application/json
```
**Respuesta**:
```json
{
  "success": true,
  "data": [
    {
      "id": 1420,
      "slug": "solo-leveling",
      "title": "Solo Leveling",
      "format": "TV",
      "status": "FINISHED",
      "year": 2024,
      "episodes_count": 12,
      "poster": "https://media.anime.nexus/covers/...",
      "banner": "https://media.anime.nexus/banners/..."
    }
  ]
}
```

#### 2. Ficha Completa del Anime
```http
GET https://api.anime.nexus/api/v1/anime/solo-leveling
Accept: application/json
```
Retorna sinopsis, géneros, puntuación de la comunidad, equivalencias con bases de datos externas (AniList ID / MyAnimeList ID) y enlaces canónicos.

#### 3. Listado de Episodios
```http
GET https://api.anime.nexus/api/v1/anime/solo-leveling/episodes
Accept: application/json
```
**Respuesta**:
```json
{
  "success": true,
  "episodes": [
    {
      "id": 28410,
      "number": 1,
      "title": "I'm Used to It",
      "thumbnail": "https://media.anime.nexus/thumbs/...",
      "has_sub": true,
      "has_dub": false
    }
  ]
}
```

---

### 7.3. Pipeline de Reproducción y Desafíos Anti-Scraping
El acceso a las fuentes de video reales se gestiona a través de endpoints protegidos como `GET /api/v1/episode/{episode_id}/servers` o `/stream`:

```
Cliente ───────> [1. Solicitud de Streams] ────────> api.anime.nexus
                    │
                    ▼ (Si es usuario invitado / anónimo)
       [2. Cloudflare Turnstile Challenge] ──> Exige ejecución JS en navegador real
                    │
                    ▼
       [3. Handshake WebSocket (gateway)]  ──> Envía device fingerprint + HMAC wireProof
                    │
                    ▼
       [4. Emisión de Token Temporal]      ──> Respuesta JSON con Servidores (.m3u8 / hosts)
```

#### Capas de Protección Activas:
1. **Cloudflare Turnstile**:
   - El reproductor web embebe un widget invisible de Turnstile (`sitekey`).
   - El desafío ejecuta cálculos criptográficos y analiza primitivas del navegador (Canvas, WebGL, AudioContext, flags `navigator.webdriver`, worker threads).
   - Genera un token efímero `cf_turnstile_response` que debe enviarse en la cabecera `x-turnstile-token` o en el cuerpo de la petición.
2. **Gateway WebSocket & WireProof**:
   - Inicia una conexión de baja latencia a `wss://gateway.anime.nexus/ws`.
   - Se intercambia una firma criptográfica **HMAC-SHA256 (`wireProof`)** calculada a partir de un nonce de sesión, timestamp y la huella del dispositivo.
3. **Por qué fallan los scrapers HTTP estándar (Python/Go puro)**:
   - Cualquier petición directa vía `requests`, `aiohttp` o `fetch` sin token Turnstile es rechazada de inmediato con `HTTP 403 Forbidden` o `429 Too Many Requests`.

---

### 7.4. Modos de Autenticación de la API
La arquitectura de WinterCMS en Anime Nexus define dos modos de resolución de streams:

| Modo de Acceso | Condición | Requisitos Anti-Bot | Viabilidad en Scraper Ligero |
| :--- | :--- | :--- | :---: |
| **`attestation`** | Usuario invitado / anónimo | Turnstile obligatorio + WebSocket WireProof | ❌ Requiere Chromium/Browser |
| **`direct`** | Usuario registrado con sesión activa | Envío de cookie `nexus_session` o Bearer Token | ✅ **100% Viable con `fetch` estándar** |

Cuando la petición incluye la cabecera `Cookie: nexus_session=...` correspondiente a una sesión válida, el backend desactiva el requisito de Turnstile para invitados y entrega el listado de servidores y enlaces directamente.

---

### 7.5. Estrategias de Implementación para Extensiones y Clientes

#### Estrategia 1: Extensión en Seanime con `ChromeDP` (Modo Invitado / Automático)
Aprovecha que el runtime de Seanime expone bindings nativos de Chromium (`ChromeDP`):
```typescript
import { AnimeProvider, EpisodeDetails, EpisodeServer } from "./online-streaming-provider";

export default class AnimeNexusProvider extends AnimeProvider {
    async findEpisodeServer(episode: EpisodeDetails, server: string): Promise<EpisodeServer> {
        // 1. Levanta Chromium headless en segundo plano
        const browser = await ChromeDP.newBrowser({
            headless: true,
            timeout: 25,
            userAgent: "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        });

        try {
            let masterPlaylist = "";

            // 2. Intercepta el tráfico de red mediante Chrome DevTools Protocol (CDP)
            browser.listenTarget((ev: any) => {
                if (ev.method === "Network.requestWillBeSent") {
                    const url = ev.params?.request?.url || "";
                    if (url.includes(".m3u8") && !masterPlaylist) {
                        masterPlaylist = url;
                    }
                }
            });

            // 3. Navega al reproductor oficial (deja que Turnstile se resuelva naturalmente)
            await browser.navigate(`https://anime.nexus/watch/${episode.id}`);
            await browser.waitVisible("video, .nexus-player-container");

            return {
                server: "NexusStream",
                headers: {
                    "Referer": "https://anime.nexus/",
                    "Origin": "https://anime.nexus"
                },
                videoSources: [
                    {
                        url: masterPlaylist,
                        type: "m3u8",
                        quality: "1080p",
                        subtitles: []
                    }
                ]
            };
        } finally {
            await browser.close();
        }
    }
}
```

#### Estrategia 2: Extensión en Seanime con Sesión Directa (`UserConfig`)
Permite al usuario ingresar su cookie de sesión desde los ajustes de la extensión en la interfaz de Seanime:
```typescript
export default class AnimeNexusDirectProvider extends AnimeProvider {
    async findEpisodeServer(episode: EpisodeDetails, server: string): Promise<EpisodeServer> {
        // Carga la cookie de sesión configurada por el usuario en Seanime
        const sessionCookie = UserConfig.getString("nexus_session");

        const response = await fetch(`https://api.anime.nexus/api/v1/episode/${episode.id}/servers`, {
            headers: {
                "Cookie": `nexus_session=${sessionCookie}`,
                "Accept": "application/json",
                "Referer": "https://anime.nexus/"
            }
        });

        const data = await response.json();
        // data.servers contiene los enlaces directos sin pasar por Turnstile
        return {
            server: data.servers[0].name,
            headers: { "Referer": "https://anime.nexus/" },
            videoSources: data.servers[0].sources
        };
    }
}
```

---

### 7.6. Matriz de Complejidad Comparativa de Fuentes

| Proveedor | Protección Anti-Bot | Protocolo de Resolución | Velocidad de Extracción | Facilidad en Puro JS |
| :--- | :--- | :--- | :---: | :---: |
| **Kawaii Animes** | Ninguna (API / SQLite abierta) | Local DB + Unpack Dean Edwards | **Ultra-rápido** (< 100ms) | ⭐⭐⭐⭐⭐ (Trivial) |
| **AnimeX** | Token XOR / Enmascaramiento JPEG | GraphQL + Descifrado XOR `/uwu/` | **Ultra-rápido** (< 200ms) | ⭐⭐⭐⭐⭐ (Trivial) |
| **JKAnime** | Scraper HTML dinámico | Regex sobre HTML + Redirecciones | **Rápido** (~ 400ms) | ⭐⭐⭐⭐ (Sencillo) |
| **TioAnime** | Scraper HTML dinámico | Regex sobre scripts JS | **Rápido** (~ 400ms) | ⭐⭐⭐⭐ (Sencillo) |
| **Anime Nexus** | **Cloudflare Turnstile + WireProof WS** | Headless ChromeDP o Sesión Directa | **Moderado** (~ 1.5s - 3s con headless) | ⭐⭐ (Requiere CDP o Login) |

---

## 8. Arquitectura de Extensiones y Motor de Streaming en Seanime

Este apartado detalla el funcionamiento interno de Seanime a nivel de backend, motor de ejecución JavaScript y reproducción de video para el desarrollo de proveedores de streaming online (`onlinestream-provider`).

### 8.1. Runtime de Ejecución (Goja VM)
Seanime **no** ejecuta las extensiones en Node.js ni dentro del motor Chromium/Electron de la interfaz. Las extensiones se ejecutan en el servidor backend en Go mediante el intérprete **Goja** (`backend/internal/goja/`):
* **Aislamiento**: Cada extensión opera en un sandbox con su propio pool de máquinas virtuales (`goja_runtime_manager.go`), permitiendo concurrencia segura y cancelación de tareas con timeouts.
* **Transpilación**: Las extensiones se escriben comúnmente en TypeScript (`payload.ts`) y se transpilan a JavaScript estándar antes de cargarse en Goja.

### 8.2. Bindings Nativos Expuestos a JavaScript
El runtime de Seanime inyecta utilidades globales de Go al contexto de JavaScript para suplir las limitaciones del entorno sin navegador tradicional:

| API Global | Implementación Backend | Propósito |
| :--- | :--- | :--- |
| `fetch(url, options)` | Cliente HTTP nativo de Go (`fetch.go`) | Peticiones HTTP de alto rendimiento con cookies, cabeceras personalizadas y manejo de redirecciones. |
| `Document` | Parser HTML Goquery (`document.go`) | Parseo del DOM estilo jQuery (`new Document(html)`, `doc.find('selector')`, `.text()`, `.attr('href')`). |
| `Crypto` | Criptografía Go (`crypto.go`, `crypto_encoders.go`) | Soporte para hashing (MD5, SHA-1, SHA-256), cifrado simétrico (AES-CBC, AES-GCM) y codificadores (Base64, Hex). |
| `ChromeDP` | Automatización Chromium (`chromedp.go`) | Control de instancias de Chromium headless mediante DevTools Protocol (CDP) para resolver desafíos dinámicos o Cloudflare. |
| `console` | Logger Zerolog y WebSockets (`console.go`) | Emisión de logs en vivo en la consola del servidor y en la UI web de Seanime. |
| `UserConfig` | Configuración persistente del usuario | Acceso a variables de usuario definidas desde los ajustes de la extensión en la UI. |

### 8.3. Contrato del Proveedor de Streaming (`AnimeProvider`)
Toda extensión de tipo `onlinestream-provider` debe extender la clase abstracta `AnimeProvider` e implementar cuatro métodos esenciales:

```typescript
declare abstract class AnimeProvider {
    // 1. Búsqueda por metadatos (título, año, formato, etc.)
    search(opts: SearchOptions): Promise<SearchResult[]>;

    // 2. Extracción de lista de episodios a partir del ID del anime
    findEpisodes(id: string): Promise<EpisodeDetails[]>;

    // 3. Extracción de fuentes de video y subtítulos para un episodio y servidor
    findEpisodeServer(episode: EpisodeDetails, server: string): Promise<EpisodeServer>;

    // 4. Configuración del proveedor (servidores soportados y doblajes)
    getSettings(): Settings;
}
```

#### Estructura del Resultado (`EpisodeServer`):
```typescript
{
    server: "LuluStream",
    headers: {
        "Referer": "https://luluvdoo.com/",
        "User-Agent": "Mozilla/5.0 ..."
    },
    videoSources: [
        {
            url: "https://.../master.m3u8",
            type: "m3u8", // "m3u8" | "mp4"
            quality: "1080p",
            subtitles: [
                { id: "es", url: "https://.../sub.vtt", language: "Spanish", isDefault: true }
            ]
        }
    ]
}
```

### 8.4. Automatización con `ChromeDP` en Extensiones
Para sitios protegidos por CAPTCHA, Cloudflare Turnstile o SPA reactivas complejas, la API de Seanime permite instanciar un navegador headless:

```typescript
// Creación de una sesión headless
const browser = await ChromeDP.newBrowser({
    headless: true,
    timeout: 30, // segundos
    userAgent: "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36..."
});

try {
    // Navegación e interacción con el DOM
    await browser.navigate(url);
    await browser.waitVisible("#player-container");

    // Intercepción de eventos de red mediante CDP
    browser.listenTarget((event) => {
        if (event.method === "Network.requestWillBeSent") {
            const reqUrl = event.params.request.url;
            if (reqUrl.includes(".m3u8")) {
                console.log("Master HLS detectado:", reqUrl);
            }
        }
    });

    // Ejecución de scripts dentro de la página
    const result = await browser.evaluate("window.__STREAM_DATA__");
} finally {
    // Liberación obligatoria del proceso Chromium
    await browser.close();
}
```

### 8.5. Estructura de Paquetes y Despliegue de Extensiones
Las extensiones de Seanime residen en carpetas individuales dentro del directorio de configuración:
* **Linux**: `~/.config/Seanime/extensions/{extensionId}/` o `~/.config/aniting/extensions/{extensionId}/`
* **Estructura requerida**:
  - `manifest.json`: Metadatos del proveedor (id, nombre, versión, tipo, autor, icono).
  - `payload.ts` o `payload.js`: Código fuente transpilado con la implementación del proveedor.
  - `extension.json`: Configuración de estado registrada por el backend.


