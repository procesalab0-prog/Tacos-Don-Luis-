# Tacos Don Luis

Sistema web para la sucursal Punto Cañada.

## Rutas

- `/`: demo administrativa original mientras se recibe la landing definitiva.
- `/pedir/`: menú, carrito, checkout, pedidos como invitado y seguimiento.
- `/admin/`: acceso directo a la demo administrativa.
- `/repartidor/`: ruta reservada para el diseño de la fase 2.

## Servicios

- Vercel: alojamiento web.
- Supabase: base de datos, autenticación, menú, configuración y pedidos.

La aplicación del cliente calcula precios y crea pedidos mediante una función
segura en Supabase. Las claves secretas nunca se incluyen en el navegador.
