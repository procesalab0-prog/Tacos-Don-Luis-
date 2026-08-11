self.__DON_LUIS_PWA_VERSION__='2.11.9';
// release-sync: 2.11.9
self.addEventListener('install',()=>self.skipWaiting());
self.addEventListener('activate',event=>event.waitUntil(self.clients.claim()));
self.addEventListener('fetch',()=>{});
