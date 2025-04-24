const CACHE_NAME = 'tashil-cache-v1';

// List of URLs to cache (frontend, portal, and backend)
const URLS_TO_CACHE = [
  '/',                      // Homepage
  '/my',                   // Portal dashboard
  '/web/login',            // Login page
  '/web',                  // Backend dashboard
  '/web/webclient/bootstrap_translations',
  '/web/image/res.company/1/logo',  // Company logo
  '/offline.html',         // Offline fallback
];

// Install event to pre-cache required assets
self.addEventListener('install', function (event) {
  event.waitUntil(
    caches.open(CACHE_NAME).then(function (cache) {
      return cache.addAll(URLS_TO_CACHE);
    })
  );
});

// Intercept fetches and respond from cache or fallback
self.addEventListener('fetch', function (event) {
  event.respondWith(
    fetch(event.request).catch(() => {
      return caches.match(event.request).then(function (response) {
        return response || caches.match('/offline.html');
      });
    })
  );
});