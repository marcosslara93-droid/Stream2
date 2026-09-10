# StreamFlix PRO

Aplicación web IPTV/OTT premium, cinematográfica y lista para producción, conectada a cualquier backend compatible con **Xtream Codes**. Vanilla JS (ES Modules) + HTML + CSS — sin framework, sin build step — desplegada como **Cloudflare Pages** con **Pages Functions** de backend y **D1** para sincronización entre dispositivos.

> ⚠️ Usa esta aplicación únicamente con servicios IPTV y contenido para los que tengas autorización.

---

## 1. Instalación

No hay paso de build: es HTML/CSS/JS servido tal cual. Para desarrollo local necesitas [Wrangler](https://developers.cloudflare.com/workers/wrangler/) (CLI de Cloudflare) para que las Pages Functions (`/api/*`) funcionen igual que en producción.

```bash
npm install -g wrangler
wrangler pages dev . --d1=DB=streamflix_db
```

Esto sirve el sitio en `http://localhost:8788` con las Functions y D1 activas. Si solo quieres ver el frontend sin backend (sin progreso/favoritos sincronizados), cualquier servidor estático simple funciona:

```bash
npx serve .
```

## 2. Desarrollo

Estructura de carpetas:

```
/
├─ index.html              # Punto de entrada
├─ manifest.json, sw.js     # PWA
├─ css/                     # tokens, base, components, player, login, animations
├─ js/
│  ├─ app.js                # Bootstrap: router, navbar, auth guard, modo TV
│  ├─ router.js             # SPA router con historial (WebView-safe)
│  ├─ lib/                  # logger, dom helpers, eventBus, focusManager, imageLoader
│  ├─ state/store.js        # Slices de estado: auth, content, player, ui, user
│  ├─ services/
│  │  ├─ xtream/xtreamClient.js     # Cliente Xtream Codes (retry/timeout/backoff)
│  │  ├─ normalize/normalizer.js    # Normaliza datos incompletos del proveedor
│  │  ├─ cache/                     # IndexedDB + stale-while-revalidate
│  │  ├─ storage/localStore.js      # localStorage / sessionStorage
│  │  └─ repository.js              # Orquesta Client + Normalizer + Cache
│  ├─ components/            # navbar, hero, cards, contentRow, modal, estados, EPG
│  └─ features/              # auth, home, movies, series, live, player, search,
│                             # favorites, history, profiles, settings
├─ functions/api/            # Cloudflare Pages Functions (backend)
│  ├─ xtream.js               # Proxy a player_api.php (evita CORS, oculta credenciales)
│  ├─ progress.js             # Continuar viendo → D1
│  ├─ favorites.js            # Mi lista → D1
│  └─ profiles.js             # Perfiles + PIN (hasheado) → D1
├─ schema.sql                 # Esquema D1
└─ wrangler.toml
```

### Flujo de datos

```
Xtream API (player_api.php)
  ↓  (vía /api/xtream, proxy sin CORS)
XtreamClient          — timeout, retry, backoff, manejo de errores HTTP/JSON
  ↓
Normalizer            — normalizeMovie/Series/Season/Episode/Channel/EPG/Account
  ↓
Repository            — orquesta cliente + normalizer + cache
  ↓
CacheManager (IndexedDB) — stale-while-revalidate: muestra caché al instante,
  ↓                        refresca en segundo plano
Estado (state/store.js) — slices independientes por dominio
  ↓
UI (componentes vanilla JS, sin virtual DOM)
```

La UI **nunca** toca la respuesta cruda de Xtream: todo pasa por el Normalizer, así que un proveedor que devuelve campos faltantes, `null`, números como string, o URLs rotas nunca rompe una tarjeta o una página de detalle.

## 3. Xtream API

`XtreamClient` (`js/services/xtream/xtreamClient.js`) soporta:

- `get_live_categories`, `get_live_streams`, `get_short_epg`
- `get_vod_categories`, `get_vod_streams`, `get_vod_info`
- `get_series_categories`, `get_series`, `get_series_info`
- Cuentas: `player_api.php` sin `action` → `user_info` / `server_info`

Todas las llamadas pasan por `/api/xtream` (Pages Function) — nunca directo desde el navegador — para evitar problemas de CORS/mixed-content y no exponer credenciales en peticiones cross-origin. Las URLs de **streaming** (`liveStreamUrl`, `vodStreamUrl`, `seriesStreamUrl`) sí apuntan directo al proveedor, porque el `<video>` necesita una URL seekable real.

Nunca se registran passwords/tokens: `js/lib/logger.js` redacta automáticamente cualquier campo sensible antes de imprimir en consola.

## 4. Reproductor

`js/features/player/player.js` implementa:

- HLS.js para `.m3u8` (con fallback a reproducción nativa para `.mp4`/`.ts` cuando el navegador lo soporta)
- Controles custom: play/pause, seek, volumen, fullscreen, Picture-in-Picture, selector de calidad (niveles HLS reales), skip ±10s, auto-hide de controles
- **Reproducción continua obligatoria**: detecta los últimos 25s de un episodio, muestra la tarjeta "Siguiente episodio" con cuenta regresiva y autoplay
- Guardado de progreso cada 5s en IndexedDB (+ sync best-effort a D1 vía `/api/progress`)
- Recuperación de errores con backoff exponencial (máx. 3 reintentos automáticos antes de mostrar error + botón reintentar)

## 5. Modo TV / 10-foot UI

`js/lib/focusManager.js` implementa navegación espacial por D-pad (vecino más cercano en la dirección pulsada, no solo orden del DOM) sobre cualquier elemento `.focusable`. Se activa automáticamente si se detecta user-agent de Android TV/Google TV/Tizen/WebOS, o pantalla grande sin touch. La clase `.mode-tv` en `<html>` escala tipografía, tarjetas y márgenes de seguridad para lectura a distancia.

## 6. WebView

- El estado de progreso se persiste cada 5s (no solo al cerrar), para sobrevivir a que el sistema operativo mate el WebView en segundo plano.
- `visibilitychange` guarda la última ruta para poder restaurar contexto.
- El botón "atrás" del sistema (`Backspace`/`Escape` mapeado por `focusManager`, o el botón físico en Android) cierra el reproductor antes de navegar atrás, para no perder el WebView en medio de una reproducción.

## 7. Backend (Cloudflare Pages Functions + D1)

1. Crea la base de datos:
   ```bash
   wrangler d1 create streamflix_db
   ```
2. Copia el `database_id` que te da el comando anterior a `wrangler.toml`.
3. Aplica el esquema:
   ```bash
   wrangler d1 execute streamflix_db --file=./schema.sql
   ```
4. Despliega:
   ```bash
   wrangler pages deploy .
   ```

Las credenciales Xtream del usuario **nunca** se guardan en D1 ni en el código — viven solo en `sessionStorage` del navegador (y opcionalmente host/usuario, nunca la contraseña, en `localStorage` si el usuario marca "Recordar servidor").

## 8. Troubleshooting

| Síntoma | Causa probable |
|---|---|
| "Usuario o contraseña incorrectos" al conectar | El proveedor devolvió 401/403, o `user_info.status` no es `Active` |
| Catálogo vacío tras conectar | El proveedor no tiene VOD/series, o `get_vod_streams`/`get_series` no está implementado por ese panel |
| Video no reproduce, error tras 3 reintentos | Revisa que el `container_extension` normalizado coincida con lo que sirve el proveedor; algunos requieren `.ts` en vivo en vez de `.m3u8` |
| EPG vacío | El proveedor no expone `get_short_epg` o el canal no tiene `epg_channel_id` |
| Cambios de código no se reflejan | No hay build/cache-busting de módulos — haz hard-refresh o sube el número de versión del `CACHE` en `sw.js` |

## 9. Próximos pasos sugeridos

Este proyecto cubre el flujo principal completo (login → catálogo → detalle → reproducción → continuar viendo → siguiente episodio → live TV/EPG → búsqueda → mi lista → perfiles → configuración), pero quedan mejoras "nice-to-have" del documento original que valen la pena para producción a mayor escala:
- Virtualización de listas para catálogos de +5.000 títulos
- Tests automatizados (unitarios para Normalizer/XtreamClient, e2e para el flujo de login→reproducción)
- Subtítulos externos (WebVTT) si el proveedor los expone
- Recomendaciones más sofisticadas basadas en historial real de visualización
