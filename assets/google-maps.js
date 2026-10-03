(() => {
  let loading;
  const configured = () => Boolean(window.DON_LUIS_MAPS?.apiKey && window.DON_LUIS_MAPS?.mapId);
  function load() {
    if (!configured()) return Promise.reject(Error('Google Maps todavía no está configurado'));
    if (loading) return loading;
    loading = new Promise((resolve, reject) => {
      const script = document.createElement('script');
      const params = new URLSearchParams({key: window.DON_LUIS_MAPS.apiKey, v: 'quarterly', loading: 'async', language: 'es', region: 'MX', callback: '__donLuisGoogleReady', auth_referrer_policy: 'origin'});
      const timer = setTimeout(() => reject(Error('Google Maps tardó demasiado')), 15000);
      window.__donLuisGoogleReady = () => {clearTimeout(timer); resolve();};
      script.onerror = () => {clearTimeout(timer); reject(Error('No se pudo cargar Google Maps'));};
      script.src = 'https://maps.googleapis.com/maps/api/js?' + params;
      script.async = true;
      document.head.appendChild(script);
    });
    return loading;
  }
  async function create(el, initial, onPick, onError) {
    await load();
    const [{Map}, {AdvancedMarkerElement}, {PlaceAutocompleteElement}] = await Promise.all(['maps','marker','places'].map(name => google.maps.importLibrary(name)));
    const map = new Map(el, {center: initial, zoom: 14, mapId: window.DON_LUIS_MAPS.mapId, streetViewControl: false, mapTypeControl: false, fullscreenControl: false, clickableIcons: false});
    let marker;
    map.addListener('click', e => e.latLng && onPick(e.latLng.lat(), e.latLng.lng()));
    const search = new PlaceAutocompleteElement({includedRegionCodes: ['mx'], locationBias: {center: initial, radius: 10000}});
    search.setAttribute('aria-label', 'Buscar dirección de entrega');
    search.style.cssText = 'display:block;margin-bottom:10px;width:100%;';
    el.before(search);
    search.addEventListener('gmp-select', async ({placePrediction}) => {
      try {
        const place = placePrediction.toPlace();
        await place.fetchFields({fields: ['location']});
        if (place.location) {const lat=place.location.lat(),lng=place.location.lng();map.setCenter({lat,lng});map.setZoom(17);onPick(lat,lng);}
      } catch (e) {onError(e);}
    });
    return {
      getContainer: () => el,
      invalidateSize: () => {},
      setView: ([lat,lng], zoom) => {map.setCenter({lat,lng});map.setZoom(zoom);},
      pick: (lat,lng) => {if (marker) marker.position={lat,lng}; else marker=new AdvancedMarkerElement({map,position:{lat,lng},title:'Punto de entrega'});},
      remove: () => {search.remove();if(marker)marker.map=null;google.maps.event.clearInstanceListeners(map);el.replaceChildren();}
    };
  }
  async function reverse(lat,lng) {
    await load();
    const {Geocoder} = await google.maps.importLibrary('geocoding');
    const {results} = await new Geocoder().geocode({location:{lat,lng}});
    const components=results[0]?.address_components||[];
    const get=(...types)=>components.find(c=>types.some(t=>c.types.includes(t)))?.long_name||'';
    return {road:get('route'),house_number:get('street_number'),neighbourhood:get('neighborhood','sublocality_level_1','sublocality')};
  }
  window.DonLuisGoogle = {configured,create,reverse};
})();
