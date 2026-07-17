// AmEx Mivtza Service Worker
// Bump CACHE_NAME to force all clients to pick up the new version.
const CACHE_NAME = 'mivtza-v67';

// The shell files to pre-cache on install. Supabase/esm.sh calls are always
// network-first so live data is never stale; only the app shell is cached.
const PRECACHE_URLS = [
  './',
  './index.html',
  './manifest.json',
  './admin-manifest.json',
  './icon-192.png',
  './icon-512.png',
];

// ── Install: pre-cache the shell ─────────────────────────────────────────────
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(PRECACHE_URLS))
  );
  // Activate immediately without waiting for existing tabs to close.
  self.skipWaiting();
});

// ── Activate: delete old caches ───────────────────────────────────────────────
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE_NAME).map((k) => caches.delete(k)))
    )
  );
  // Take control of all open tabs immediately.
  self.clients.claim();
});

// ── Fetch strategy ────────────────────────────────────────────────────────────
self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);

  // Always go network-first for Supabase API calls and esm.sh CDN imports
  // so the app never shows stale data or stale library builds.
  const isExternal =
    url.hostname.includes('supabase.co') ||
    url.hostname.includes('supabase.io') ||
    url.hostname.includes('esm.sh') ||
    url.hostname.includes('unpkg.com') ||
    url.hostname.includes('fonts.googleapis.com') ||
    url.hostname.includes('fonts.gstatic.com') ||
    url.hostname.includes('tailwindcss.com');

  if (isExternal) {
    // Network-only for external resources; if offline and uncached, fail silently.
    event.respondWith(fetch(request).catch(() => new Response('', { status: 503 })));
    return;
  }

  // Network-first for the HTML shell itself (page navigations + index.html
  // directly) so a code fix is visible the very next time a device is
  // online, without waiting on the browser to notice sw.js changed bytes
  // and cycle through install/activate first. Falls back to the cache only
  // when the network is unreachable (offline use).
  const isShellDocument = request.mode === 'navigate' || url.pathname.endsWith('/index.html') || url.pathname.endsWith('/');
  if (isShellDocument) {
    event.respondWith(
      fetch(request)
        .then((response) => {
          if (response.status === 200) {
            const clone = response.clone();
            caches.open(CACHE_NAME).then((cache) => cache.put(request, clone));
          }
          return response;
        })
        .catch(() => caches.match(request))
    );
    return;
  }

  // Cache-first for other same-origin shell assets (manifest.json, icons)
  // — these rarely change and don't affect functional correctness.
  event.respondWith(
    caches.match(request).then((cached) => {
      if (cached) return cached;
      return fetch(request).then((response) => {
        // Only cache successful same-origin GET responses.
        if (request.method === 'GET' && response.status === 200) {
          const clone = response.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(request, clone));
        }
        return response;
      });
    })
  );
});