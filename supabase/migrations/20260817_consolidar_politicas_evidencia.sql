-- Deja una sola versión de las políticas del depósito de evidencias.
--
-- POR QUÉ EXISTE ESTE ARCHIVO
--
-- La evidencia de entrega se construyó dos veces, en paralelo, y cada versión
-- guardó la foto en una ruta distinta:
--
--   20260814_delivery_evidence.sql              ->  <repartidor>/archivo.jpg
--   20260814_admin_accounts_and_delivery_...    ->  <sucursal>/<repartidor>/archivo.jpg
--
-- El portal del repartidor hoy sube con la segunda forma, que es la correcta:
-- amarra la foto a la sucursal además del repartidor. Pero las políticas de la
-- primera versión siguieron ahí, y en Postgres las políticas de un mismo
-- comando se suman con OR, no se reemplazan. El resultado es que la regla vieja
-- quedó abierta:
--
--   "repartidor sube su evidencia" permite escribir en <mi-uid>/loquesea a
--   CUALQUIER usuario con sesión — incluido un cliente que se registró para
--   pedir tacos. No es que pueda ver las entregas: es que puede usar el
--   depósito como almacenamiento gratis, sin pasar por la sucursal.
--
-- Y del lado de lectura, "staff lee toda la evidencia" no comprueba sucursal:
-- hoy solo hay una, pero al abrir la segunda cada quien vería las entregas de
-- la otra.
--
-- Aquí se borran todas las políticas del depósito, de las dos versiones, y se
-- vuelven a crear solo las que corresponden. Se puede correr las veces que sea.

-- La columna sigue viniendo de 20260814_delivery_evidence.sql; se repite aquí
-- para que este archivo deje el sistema completo aunque aquella no se haya
-- aplicado.
alter table public.driver_assignments
  add column if not exists evidence_path text;

comment on column public.driver_assignments.evidence_path is
  'Ruta dentro del depósito delivery-evidence, con la forma <sucursal>/<repartidor>/<archivo>. Nula si no se tomó foto.';

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('delivery-evidence','delivery-evidence',false, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- Versión vieja (ruta sin sucursal)
drop policy if exists "repartidor sube su evidencia" on storage.objects;
drop policy if exists "repartidor lee su evidencia" on storage.objects;
drop policy if exists "staff lee toda la evidencia" on storage.objects;
-- Versión nueva, para volver a crearla igual y que el archivo sea repetible
drop policy if exists "driver uploads branch delivery evidence" on storage.objects;
drop policy if exists "staff uploads branch delivery evidence" on storage.objects;
drop policy if exists "staff reads branch delivery evidence" on storage.objects;

-- SUBIR: el que sube tiene que ser personal activo de esa sucursal, y solo
-- puede escribir dentro de su propia carpeta. Las dos condiciones importan: la
-- primera evita que un cliente use el depósito, la segunda evita que un
-- repartidor sobreescriba la evidencia de otro.
create policy "staff uploads branch delivery evidence"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'delivery-evidence'
  and (storage.foldername(name))[1] in (
    select bm.branch_id::text
    from public.branch_memberships bm
    where bm.user_id = (select auth.uid())
      and bm.role in ('driver','owner','admin','cashier')
      and bm.is_active
  )
  and (storage.foldername(name))[2] = (select auth.uid())::text
);

-- LEER: el repartidor ve lo suyo; caja y administración ven todo lo de su
-- sucursal, que es lo que sirve para aclarar un reclamo. Nadie ve otra
-- sucursal.
create policy "staff reads branch delivery evidence"
on storage.objects for select to authenticated
using (
  bucket_id = 'delivery-evidence'
  and (
    (storage.foldername(name))[2] = (select auth.uid())::text
    or (storage.foldername(name))[1] in (
      select bm.branch_id::text
      from public.branch_memberships bm
      where bm.user_id = (select auth.uid())
        and bm.role in ('owner','admin','cashier')
        and bm.is_active
    )
  )
);
