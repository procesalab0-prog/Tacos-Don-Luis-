# Estado de lo desplegado en Supabase

Este archivo lleva el control de qué migraciones y qué Edge Functions ya están
aplicadas en el proyecto, para no volver a aplicarlas ni darlas por hechas sin
comprobar. Actualizar aquí cada vez que se despliegue algo.

> **Este archivo se quedó atrás.** Decía que no había nada pendiente, pero desde
> entonces entraron migraciones de dos lados a la vez. Lo de abajo es el estado
> real al 17 de agosto. Antes de dar algo por aplicado, córrele la comprobación
> que viene al final.

---

## Pendiente de aplicar

Correr en el SQL Editor **en este orden**:

| # | Archivo | Qué hace |
|---|---|---|
| 1 | `migrations/20260814_driver_settlements.sql` | Tabla `driver_settlements`. Sin esto el botón "Solicitar liquidación" del repartidor no guarda nada y administración no muestra cortes. |
| 2 | `migrations/20260814_index_driver_settlements_settled_by.sql` | Índice sobre `settled_by`. Va después de la tabla. |
| 3 | `migrations/20260817_consolidar_politicas_evidencia.sql` | Deja una sola versión de las políticas de la evidencia de entrega. **Léelo: cierra un permiso que quedó abierto.** |
| 4 | `fotos-productos.sql` | Asigna la foto a cada producto. Trae un bloque de revisión que se corre primero. |

Sobre el punto 3: la evidencia se construyó dos veces en paralelo, con rutas
distintas, y las políticas de la primera versión nunca se borraron. En Postgres
las políticas de un mismo comando se suman, así que la regla vieja dejaba a
cualquier usuario con sesión escribir en el depósito. El archivo borra las de
las dos versiones y vuelve a crear solo las correctas. Se puede correr varias
veces sin romper nada.

Los archivos `20260814_delivery_evidence.sql` y
`20260814_admin_accounts_and_delivery_evidence.sql` ya no hace falta correrlos
por separado: el 3 los deja en su estado final.

Ninguno de estos toca Edge Functions. No hay funciones pendientes de desplegar.

---

## Aplicado

| Fecha | Qué | Cómo se aplicó |
|---|---|---|
| 2026-08-12 | `20260812_order_reviews.sql` — tabla `order_reviews` con RLS | SQL Editor |
| 2026-08-12 | Edge Function `submit-review` | Panel de Supabase |
| 2026-08-13 | `20260813_driver_vehicle.sql` — columnas `vehicle_type`, `vehicle_plate`, `vehicle_color` en `driver_status` | SQL Editor |
| 2026-08-13 | Edge Function `track-order` (redespliegue: ahora devuelve `repartidor`) | Panel de Supabase |

---

## Cómo comprobar que algo sigue en pie

Las migraciones se comprueban en el SQL Editor:

```sql
-- columnas del repartidor
select column_name
from information_schema.columns
where table_schema = 'public'
  and table_name = 'driver_status'
  and column_name in ('vehicle_type','vehicle_plate','vehicle_color');

-- tabla de calificaciones
select to_regclass('public.order_reviews');

-- liquidaciones del repartidor
select to_regclass('public.driver_settlements');

-- políticas de la evidencia: deben salir EXACTAMENTE dos, y ninguna
-- que empiece con "repartidor " o "staff lee toda"
select policyname
from pg_policies
where schemaname = 'storage' and tablename = 'objects'
  and qual || coalesce(with_check,'') like '%delivery-evidence%'
order by policyname;

-- fotos de los productos: no debería quedar ninguno en null
select count(*) filter (where image_url is null) as sin_foto, count(*) as total
from public.products
where branch_id = (select id from public.branches where slug = 'punto-canada');
```

Las Edge Functions se comprueban por su comportamiento, no por el SQL. **Una
migración aplicada no sirve de nada si la función que lee esas columnas no se
volvió a desplegar** — es el error más fácil de cometer:

- `track-order`: seguir un pedido con repartidor asignado en `/pedir/`. Debe salir
  la tarjeta **"TU REPARTIDOR"** con nombre, vehículo y placas.
- `submit-review`: llevar un pedido hasta *entregado*. Debe salir el modal
  **"¿Cómo estuvo tu pedido?"**, y con 1 o 2 estrellas no debe dejar enviar sin
  comentario.

---

## Al desplegar algo nuevo

Una Edge Function **no** se puede desplegar desde el SQL Editor. Dos caminos:

- **Panel:** Edge Functions → *Deploy a new function* → nombre exacto de la carpeta
  en `supabase/functions/` → pegar el contenido de su `index.ts`.
- **CLI:** `supabase functions deploy <nombre>`

Las funciones usan `SUPABASE_URL` y `SUPABASE_SERVICE_ROLE_KEY`, que Supabase
inyecta sola. No hay que configurar variables a mano.

> El `service_role` vive únicamente dentro de las Edge Functions. Nunca va en el
> código del navegador ni se pega en un chat: salta todas las políticas de RLS.
> La llave `sb_publishable_...` que sí está en el código del cliente es pública a
> propósito y no es problema.

---

## Por qué las calificaciones están hechas así

- La calificación se envía con **el mismo token de seguimiento** que ya identifica
  el pedido. Por eso los clientes invitados también pueden opinar sin tener cuenta.
- La regla de *"menos de 3 estrellas obliga a comentar"* está en tres capas: la
  interfaz, la función de servidor y un `check` en la tabla. Así no depende de que
  el navegador se porte bien.
- Las reseñas nacen con `is_published = false`. Nada aparece en la página pública
  hasta que el dueño o el administrador lo autoriza desde el panel.
- Esto sustituye a tres testimonios que estaban **inventados y escritos en el
  código**. No volver a poner reseñas ficticias: además de restar credibilidad,
  presentarlas como opiniones reales es publicidad engañosa.

## Por qué los datos del repartidor están hechos así

- Se piden **una sola vez**, la primera vez que el repartidor entra a su portal, y
  quedan guardados en `driver_status`.
- El cliente los ve a través de `track-order`, no consultando la tabla: así no se
  expone el padrón de repartidores a quien no tiene por qué verlo.
- Si un repartidor todavía no capturó sus datos, la tarjeta simplemente no aparece.
  La pantalla de seguimiento no se rompe.
