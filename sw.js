self.__DON_LUIS_PWA_VERSION__='2.5.3';\nself.addEventListener('install',()=>self.skipWaiting());
self.addEventListener('activate',event=>event.waitUntil(self.clients.claim()));
self.addEventListener('fetch',()=>{});
// release-sync: 2.5.3-final
