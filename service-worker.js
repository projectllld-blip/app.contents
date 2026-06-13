/* SeatFlow PWA Service Worker v1.0.1 */
const CACHE_VERSION = 'seatflow-pwa-v2';
const CACHE_NAME = CACHE_VERSION;

const urlsToCache = [
  './',
  './index.html',
  './manifest.webmanifest',
  './icons/icon-192.png',
  './icons/icon-256.png',
  './icons/icon-384.png',
  './icons/icon-512.png',
  'https://unpkg.com/html5-qrcode@2.3.8/html5-qrcode.min.js'
];

/* Service Worker のインストール */
self.addEventListener('install', event => {
  console.log('[Service Worker] Installing...');
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => {
        console.log('[Service Worker] Caching app shell');
        return cache.addAll(urlsToCache).catch(err => {
          console.warn('[Service Worker] Some cache items failed to cache:', err);
          // 外部CDNのキャッシュに失敗しても、アプリは動作する
          return cache.addAll(urlsToCache.filter(url => !url.startsWith('https://')));
        });
      })
      .then(() => self.skipWaiting())
  );
});

/* Service Worker のアクティベーション */
self.addEventListener('activate', event => {
  console.log('[Service Worker] Activating...');
  event.waitUntil(
    caches.keys().then(cacheNames => {
      return Promise.all(
        cacheNames.map(cacheName => {
          // 古いキャッシュを削除
          if (cacheName !== CACHE_NAME && cacheName.startsWith('seatflow-pwa-')) {
            console.log('[Service Worker] Deleting old cache:', cacheName);
            return caches.delete(cacheName);
          }
        })
      );
    }).then(() => self.clients.claim())
  );
});

/* リクエストのハンドリング */
self.addEventListener('fetch', event => {
  const { request } = event;
  const url = new URL(request.url);

  // GET リクエストのみ処理
  if (request.method !== 'GET') {
    return;
  }

  // HTMLは常にネットワークを優先し、公開後の修正版が古いキャッシュに
  // 固定されないようにする。オフライン時だけキャッシュへ戻る。
  if (request.mode === 'navigate' || url.pathname.endsWith('/index.html')) {
    event.respondWith(
      fetch(request)
        .then(response => {
          if (response && response.ok) {
            const copy = response.clone();
            caches.open(CACHE_NAME).then(cache => cache.put(request, copy));
          }
          return response;
        })
        .catch(() => caches.match(request).then(response => response || caches.match('./index.html')))
    );
    return;
  }

  // 画像やライブラリはキャッシュを優先する
  event.respondWith(
    caches.match(request)
      .then(response => {
        // キャッシュがある場合はそれを返す
        if (response) {
          return response;
        }

        // キャッシュがない場合、ネットワークからフェッチ
        return fetch(request)
          .then(response => {
            // ネットワークエラーの場合はここに到達しない
            if (!response || response.status !== 200 || response.type === 'error') {
              return response;
            }

            // 成功したレスポンスをキャッシュに保存
            const responseToCache = response.clone();
            caches.open(CACHE_NAME).then(cache => {
              cache.put(request, responseToCache);
            });

            return response;
          })
          .catch(() => {
            // ネットワークエラー時はキャッシュから返す
            // または、オフラインページを返す
            console.log('[Service Worker] Fetch failed; returning cached or offline response');
            return new Response(
              'アプリがオフラインです。インターネット接続をご確認ください。',
              { status: 503, statusText: 'Service Unavailable', headers: new Headers({ 'Content-Type': 'text/plain; charset=utf-8' }) }
            );
          });
      })
  );
});

/* メッセージハンドリング（キャッシュの更新確認用） */
self.addEventListener('message', event => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    console.log('[Service Worker] Skip waiting called');
    self.skipWaiting();
  }
  if (event.data && event.data.type === 'CHECK_FOR_UPDATE') {
    console.log('[Service Worker] Checking for updates...');
    event.ports[0].postMessage({
      type: 'UPDATE_CHECK_RESULT',
      needsUpdate: false // 実装に応じて更新判定ロジックを追加
    });
  }
});
