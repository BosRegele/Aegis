// Firebase Messaging Service Worker
// Handles background push notifications on web.
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

firebase.initializeApp({
    apiKey: 'AIzaSyBWqx2icOf8dRImzDaSbOlWq-1cPQhiwVM',
    appId: '1:483829433461:web:91d04ebab182b93957e43c',
    messagingSenderId: '483829433461',
    projectId: 'studentid-cd43b',
    authDomain: 'studentid-cd43b.firebaseapp.com',
    storageBucket: 'studentid-cd43b.firebasestorage.app',
});

const messaging = firebase.messaging();

// Handle background messages (app not in focus)
messaging.onBackgroundMessage((payload) => {
    const notification = payload.notification;
    if (!notification) return;
    self.registration.showNotification(notification.title || '', {
        body: notification.body || '',
        icon: '/icons/Icon-192.png',
    });
});
