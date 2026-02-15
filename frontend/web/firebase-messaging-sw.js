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
  const origin = self.location.origin;
  const targetUrl = route && route.startsWith('/') ? origin + route : origin;

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
