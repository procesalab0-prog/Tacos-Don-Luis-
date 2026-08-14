self.__DON_LUIS_PWA_VERSION__='2.18.2';
// release-sync: 2.18.2
const CACHE='don-luis-2.18.2';

// Solo se guardan archivos propios y estáticos. Nunca se cachean las respuestas
// de Supabase: el menú, los precios y el estado de los pedidos deben venir en vivo.
const PRECARGA=[
  '/pedir/','/pedir/index.html',
  '/assets/vendor/react-18.3.1.min.js',
  '/assets/vendor/react-dom-18.3.1.min.js',
  '/support.js',
  '/assets/logo-don-luis-oficial.svg',
  '/assets/sticker-inicio.svg','/assets/sticker-puesto.svg',
  '/assets/sticker-boleto.svg','/assets/sticker-chef.svg',
  // Se usa en la pantalla de seguimiento, que se abre en la calle y con mala señal.
  '/assets/sticker-don-luis-corriendo.png'
];

self.addEventListener('install',e=>{
  self.skipWaiting();
  // Si algún archivo falla, la instalación no debe abortar.
  e.waitUntil(caches.open(CACHE).then(c=>Promise.allSettled(PRECARGA.map(u=>c.add(u)))));
});

self.addEventListener('activate',e=>{
  e.waitUntil((async()=>{
    const nombres=await caches.keys();
    await Promise.all(nombres.filter(n=>n.startsWith('don-luis-')&&n!==CACHE).map(n=>caches.delete(n)));
    await self.clients.claim();
  })());
});

self.addEventListener('fetch',e=>{
  const req=e.request;
  if(req.method!=='GET') return;
  let url;
  try{ url=new URL(req.url); }catch(_){ return; }
  if(url.origin!==self.location.origin) return;        // Supabase, mapas y demás: siempre en vivo
  if(url.pathname.startsWith('/admin')||url.pathname.startsWith('/repartidor')) return; // portales de personal: siempre frescos

  // Navegación: primero la red, y solo si no hay señal se usa la copia guardada.
  if(req.mode==='navigate'){
    e.respondWith((async()=>{
      try{
        const r=await fetch(req);
        if(r&&r.ok) (await caches.open(CACHE)).put(req,r.clone());
        return r;
      }catch(_){
        return (await caches.match(req))||(await caches.match('/pedir/index.html'))||Response.error();
      }
    })());
    return;
  }

  // Estáticos: se responde con la copia y se actualiza en segundo plano.
  e.respondWith((async()=>{
    const guardado=await caches.match(req);
    const red=fetch(req).then(r=>{
      if(r&&r.ok&&r.type==='basic') caches.open(CACHE).then(c=>c.put(req,r.clone()));
      return r;
    }).catch(()=>null);
    return guardado||(await red)||Response.error();
  })());
});
