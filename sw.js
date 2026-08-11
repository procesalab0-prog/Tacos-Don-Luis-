self.__DON_LUIS_PWA_VERSION__='2.12.1';
// release-sync: 2.12.1
self.addEventListener('install',()=>self.skipWaiting());
self.addEventListener('activate',event=>event.waitUntil(self.clients.claim()));
self.addEventListener('fetch',()=>{});
