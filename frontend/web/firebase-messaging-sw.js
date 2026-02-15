try {
  importScripts('flutter_service_worker.js');
} catch (e) {
  // Flutter service worker is only available in release builds.
}

importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyDGnqthWFCa0PPltZOLpy5CcwXPLMCvHVU',
  authDomain: 'museikschule.firebaseapp.com',
  projectId: 'museikschule',
  storageBucket: 'museikschule.firebasestorage.app',
  messagingSenderId: '437925171777',
  appId: '1:437925171777:web:d1b1d37e4a4e5c0142ecc0',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const notification = payload.notification || {};
  const title = notification.title || 'Musikschule';
  const options = {
    body: notification.body || '',
    data: payload.data || {},
  };

  self.registration.showNotification(title, options);
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  const route = event.notification?.data?.route;
  const metadata = event.notification?.data?.metadata;
  const origin = self.location.origin;
  let targetUrl = origin;
  if (route && route.startsWith('/')) {
    const url = new URL(route, origin);
    if (metadata) {
      try {
        const parsed = JSON.parse(metadata);
        if (parsed.feed_id) {
          url.searchParams.set('feed_id', parsed.feed_id);
        }
        if (parsed.post_id) {
          url.searchParams.set('post_id', parsed.post_id);
        }
        if (parsed.student_id) {
          url.searchParams.set('student_id', parsed.student_id);
        }
      } catch (e) {
        // Ignore invalid metadata
      }
    }
    targetUrl = url.toString();
  }

  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clients) => {
      for (const client of clients) {
        if (client.url.startsWith(origin)) {
          client.focus();
          if (route) {
            client.navigate(targetUrl);
          }
          return;
        }
      }
      return self.clients.openWindow(targetUrl);
    })
  );
});
