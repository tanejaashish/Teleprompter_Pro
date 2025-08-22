// apps/web/web/service-worker.js

const CACHE_NAME = 'teleprompt-pro-v3';
const STATIC_CACHE = 'teleprompt-static-v3';
const DYNAMIC_CACHE = 'teleprompt-dynamic-v3';
const SYNC_CACHE = 'teleprompt-sync-v3';

// Assets to cache on install
const STATIC_ASSETS = [
  '/',
  '/index.html',
  '/offline.html',
  '/manifest.json',
  '/flutter.js',
  '/main.dart.js',
  '/icons/icon-72x72.png',
  '/icons/icon-96x96.png',
  '/icons/icon-128x128.png',
  '/icons/icon-144x144.png',
  '/icons/icon-152x152.png',
  '/icons/icon-192x192.png',
  '/icons/icon-384x384.png',
  '/icons/icon-512x512.png',
];

// Install event - cache static assets
self.addEventListener('install', (event) => {
  console.log('[Service Worker] Installing...');
  
  event.waitUntil(
    caches.open(STATIC_CACHE).then((cache) => {
      console.log('[Service Worker] Caching static assets');
      return cache.addAll(STATIC_ASSETS);
    })
  );
  
  // Force the waiting service worker to become the active service worker
  self.skipWaiting();
});

// Activate event - clean up old caches
self.addEventListener('activate', (event) => {
  console.log('[Service Worker] Activating...');
  
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames
          .filter((cacheName) => {
            return cacheName.startsWith('teleprompt-') && 
                   cacheName !== STATIC_CACHE &&
                   cacheName !== DYNAMIC_CACHE &&
                   cacheName !== SYNC_CACHE;
          })
          .map((cacheName) => {
            console.log('[Service Worker] Deleting old cache:', cacheName);
            return caches.delete(cacheName);
          })
      );
    })
  );
  
  // Take control of all pages immediately
  self.clients.claim();
});

// Fetch event - serve from cache or network
self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);
  
  // API requests - network first, fallback to cache
  if (url.pathname.startsWith('/api/')) {
    event.respondWith(networkFirstStrategy(request));
  }
  // Static assets - cache first, fallback to network
  else if (isStaticAsset(url.pathname)) {
    event.respondWith(cacheFirstStrategy(request));
  }
  // Dynamic content - stale while revalidate
  else {
    event.respondWith(staleWhileRevalidateStrategy(request));
  }
});

// Cache strategies
async function cacheFirstStrategy(request) {
  const cachedResponse = await caches.match(request);
  if (cachedResponse) {
    return cachedResponse;
  }
  
  try {
    const networkResponse = await fetch(request);
    if (networkResponse.ok) {
      const cache = await caches.open(STATIC_CACHE);
      cache.put(request, networkResponse.clone());
    }
    return networkResponse;
  } catch (error) {
    return caches.match('/offline.html');
  }
}

async function networkFirstStrategy(request) {
  try {
    const networkResponse = await fetch(request);
    if (networkResponse.ok) {
      const cache = await caches.open(DYNAMIC_CACHE);
      cache.put(request, networkResponse.clone());
    }
    return networkResponse;
  } catch (error) {
    const cachedResponse = await caches.match(request);
    if (cachedResponse) {
      return cachedResponse;
    }
    return new Response(
      JSON.stringify({ error: 'Network error and no cached data available' }),
      { headers: { 'Content-Type': 'application/json' } }
    );
  }
}

async function staleWhileRevalidateStrategy(request) {
  const cachedResponse = await caches.match(request);
  
  const fetchPromise = fetch(request).then((networkResponse) => {
    if (networkResponse.ok) {
      const cache = caches.open(DYNAMIC_CACHE);
      cache.then((cache) => cache.put(request, networkResponse.clone()));
    }
    return networkResponse;
  });
  
  return cachedResponse || fetchPromise;
}

// Background sync for offline operations
self.addEventListener('sync', (event) => {
  console.log('[Service Worker] Background sync triggered');
  
  if (event.tag === 'sync-scripts') {
    event.waitUntil(syncScripts());
  } else if (event.tag === 'sync-recordings') {
    event.waitUntil(syncRecordings());
  } else if (event.tag === 'sync-all') {
    event.waitUntil(syncAll());
  }
});

async function syncScripts() {
  const cache = await caches.open(SYNC_CACHE);
  const requests = await cache.keys();
  const scriptRequests = requests.filter(req => 
    req.url.includes('/api/scripts'));
  
  const promises = scriptRequests.map(async (request) => {
    try {
      const cachedResponse = await cache.match(request);
      const data = await cachedResponse.json();
      
      const response = await fetch(request, {
        method: request.method,
        headers: request.headers,
        body: JSON.stringify(data),
      });
      
      if (response.ok) {
        await cache.delete(request);
      }
    } catch (error) {
      console.error('[Service Worker] Sync failed for:', request.url);
    }
  });
  
  return Promise.all(promises);
}

async function syncRecordings() {
  // Similar to syncScripts but for recordings
  const cache = await caches.open(SYNC_CACHE);
  const requests = await cache.keys();
  const recordingRequests = requests.filter(req => 
    req.url.includes('/api/recordings'));
  
  // Process recording uploads
  for (const request of recordingRequests) {
    try {
      const cachedResponse = await cache.match(request);
      const formData = await cachedResponse.formData();
      
      const response = await fetch(request, {
        method: 'POST',
        body: formData,
      });
      
      if (response.ok) {
        await cache.delete(request);
        
        // Notify client of successful upload
        const clients = await self.clients.matchAll();
        clients.forEach(client => {
          client.postMessage({
            type: 'recording-uploaded',
            url: request.url,
          });
        });
      }
    } catch (error) {
      console.error('[Service Worker] Recording sync failed:', error);
    }
  }
}

async function syncAll() {
  await Promise.all([
    syncScripts(),
    syncRecordings(),
  ]);
}

// Push notifications
self.addEventListener('push', (event) => {
  console.log('[Service Worker] Push received');
  
  let data = {
    title: 'TelePrompt Pro',
    body: 'You have a new notification',
    icon: '/icons/icon-192x192.png',
    badge: '/icons/badge-72x72.png',
  };
  
  if (event.data) {
    try {
      data = event.data.json();
    } catch (e) {
      data.body = event.data.text();
    }
  }
  
  const options = {
    body: data.body,
    icon: data.icon || '/icons/icon-192x192.png',
    badge: data.badge || '/icons/badge-72x72.png',
    vibrate: [200, 100, 200],
    data: data.data || {},
    actions: data.actions || [],
    tag: data.tag || 'default',
    requireInteraction: data.requireInteraction || false,
  };
  
  event.waitUntil(
    self.registration.showNotification(data.title, options)
  );
});

// Notification click handler
self.addEventListener('notificationclick', (event) => {
  console.log('[Service Worker] Notification clicked');
  
  event.notification.close();
  
  const urlToOpen = event.notification.data?.url || '/';
  
  event.waitUntil(
    clients.matchAll({ type: 'window' }).then((windowClients) => {
      // Check if there's already a window/tab open
      for (const client of windowClients) {
        if (client.url === urlToOpen && 'focus' in client) {
          return client.focus();
        }
      }
      // Open new window if not found
      if (clients.openWindow) {
        return clients.openWindow(urlToOpen);
      }
    })
  );
});

// Periodic background sync (for modern browsers)
self.addEventListener('periodicsync', (event) => {
  if (event.tag === 'content-sync') {
    event.waitUntil(periodicSync());
  }
});

async function periodicSync() {
  // Check for updates and sync data
  console.log('[Service Worker] Periodic sync running');
  
  try {
    // Check for app updates
    const response = await fetch('/api/version');
    const data = await response.json();
    
    if (data.version !== CACHE_NAME) {
      // New version available, update caches
      const clients = await self.clients.matchAll();
      clients.forEach(client => {
        client.postMessage({
          type: 'update-available',
          version: data.version,
        });
      });
    }
    
    // Sync any pending data
    await syncAll();
  } catch (error) {
    console.error('[Service Worker] Periodic sync failed:', error);
  }
}

// Helper functions
function isStaticAsset(pathname) {
  const staticExtensions = [
    '.js', '.css', '.png', '.jpg', '.jpeg', 
    '.gif', '.svg', '.ico', '.woff', '.woff2'
  ];
  return staticExtensions.some(ext => pathname.endsWith(ext));
}

// Message handler for client communication
self.addEventListener('message', (event) => {
  console.log('[Service Worker] Message received:', event.data);
  
  if (event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  } else if (event.data.type === 'CACHE_URLS') {
    event.waitUntil(
      caches.open(DYNAMIC_CACHE).then((cache) => {
        return cache.addAll(event.data.urls);
      })
    );
  } else if (event.data.type === 'CLEAR_CACHE') {
    event.waitUntil(
      caches.keys().then((cacheNames) => {
        return Promise.all(
          cacheNames.map((cacheName) => {
            if (cacheName.startsWith('teleprompt-')) {
              return caches.delete(cacheName);
            }
          })
        );
      })
    );
  }
});