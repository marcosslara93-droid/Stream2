const CACHE = 'streamflix-shell-v1';
const SHELL = [
  '/', '/index.html', '/manifest.json',
  '/css/tokens.css', '/css/base.css', '/css/login.css', '/css/components.css', '/css/player.css', '/css/animations.css',
  '/js/app.js',
];

self.addEventListener('install', (event) => {
  event.waitUntil(caches.open(CACHE).then((c) => c.addAll(SHELL)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

// Network-first for API/data, cache-first for the static app shell.
// Streaming media (m3u8/ts/mp4) is intentionally never intercepted here —
// it must go straight to the network for seeking/range requests to work.
self.addEventListener('fetch', (event) => {
  const { request } = event;
  if (request.method !== 'GET') return;
  if (/\.(m3u8|ts|mp4|mkv)(\?|$)/i.test(request.url)) return;
  if (request.url.includes('/api/')) return;

  event.respondWith(
    caches.match(request).then((cached) => cached || fetch(request).then((res) => {
      const clone = res.clone();
      caches.open(CACHE).then((c) => c.put(request, clone));
      return res;
    }).catch(() => cached))
  );
});
