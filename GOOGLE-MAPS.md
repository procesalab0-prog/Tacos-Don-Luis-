# Google Maps para Don Luis

Pasos para la persona responsable del negocio:

1. Entrar con una cuenta de Google que controle Don Luis a https://console.cloud.google.com/. Crear un proyecto llamado **Don Luis — Mapas**.
2. Abrir **Facturación** y crear una cuenta de facturación. Elegir México y MXN cuando estén disponibles; completar los datos fiscales del negocio y agregar su forma de pago. Vincular esa cuenta al proyecto. El responsable debe completar personalmente la tarjeta y aceptar las condiciones.
3. En **APIs y servicios → Biblioteca**, habilitar **Maps JavaScript API**, **Places API (New)** y **Geocoding API**.
4. En **Facturación → Presupuestos y alertas**, crear un presupuesto mensual inicial de **$400 MXN** con avisos al 50%, 80% y 100%. Es una alerta, no un tope automático: configurar también cuotas de solicitudes por día para cada API según el tamaño del piloto.
5. En **APIs y servicios → Credenciales**, crear una clave API para el sitio. Restringirla a **Sitios web** y a los dominios exactos que use Don Luis en producción. En restricciones de API, permitir solo las tres APIs anteriores. Usar una clave distinta para pruebas locales; no dejar ninguna clave sin restricciones.
6. En **Google Maps Platform → Administración de mapas**, crear un **ID de mapa para JavaScript**. Compartir con quien configura la app el ID del proyecto, la clave pública restringida y ese ID de mapa; no compartir contraseñas ni datos de tarjeta.

Configuración técnica preparada: `assets/maps-config.js`. Hasta que tenga una clave e ID de mapa válidos, la app conserva el mapa actual. La clave del navegador es pública por diseño; sus restricciones son obligatorias.

Después de configurarlo hay que probar búsqueda de direcciones, ubicación, punto manual, límites de cobertura y apertura de rutas en dos teléfonos reales, además de comprobar el consumo en Google Cloud.

Guías oficiales:
- https://developers.google.com/maps/get-started
- https://developers.google.com/maps/documentation/javascript/get-api-key
- https://developers.google.com/maps/billing-and-pricing/manage-costs
