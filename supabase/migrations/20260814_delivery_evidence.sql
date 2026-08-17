-- Evidencia fotográfica de entrega.
--
-- El botón existía en el portal del repartidor pero solo mostraba un aviso de
-- "se habilitará más adelante". Esto le da respaldo real: un depósito privado
-- donde el repartidor sube la foto y solo caja y administración pueden verla.

alter table public.driver_assignments
  add column if not exists evidence_path text;

comment on column public.driver_assignments.evidence_path is
  'Ruta dentro del depósito delivery-evidence. Nula si no se tomó foto.';

-- Depósito privado: nadie puede leerlo con solo saber la URL.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('delivery-evidence','delivery-evidence',false, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update
  set public = false,
      file_size_limit = 5242880,
      allowed_mime_types = array['image/jpeg','image/png','image/webp'];

-- ─────────────────────────────────────────────────────────────────────────────
-- OJO: las políticas de este archivo quedaron obsoletas.
--
-- Guardaban la foto en <repartidor>/archivo.jpg. El portal hoy sube en
-- <sucursal>/<repartidor>/archivo.jpg, y con esa ruta estas reglas dejaban
-- entrar a cualquier usuario con sesión. Se reemplazan por completo en
-- 20260817_consolidar_politicas_evidencia.sql, que es el archivo que manda.
--
-- Se dejan escritas y comentadas, y no borradas, para que quede claro qué se
-- había creado en caso de que este archivo ya se hubiera aplicado: esas
-- políticas siguen vivas en la base hasta correr el de 20260817.
-- ─────────────────────────────────────────────────────────────────────────────
--
-- drop policy if exists "repartidor sube su evidencia" on storage.objects;
-- create policy "repartidor sube su evidencia" on storage.objects
--   for insert to authenticated with check (
--     bucket_id = 'delivery-evidence'
--     and (storage.foldername(name))[1] = auth.uid()::text
--   );
--
-- drop policy if exists "repartidor lee su evidencia" on storage.objects;
-- create policy "repartidor lee su evidencia" on storage.objects
--   for select to authenticated using (
--     bucket_id = 'delivery-evidence'
--     and (storage.foldername(name))[1] = auth.uid()::text
--   );
--
-- drop policy if exists "staff lee toda la evidencia" on storage.objects;
-- create policy "staff lee toda la evidencia" on storage.objects
--   for select to authenticated using (
--     bucket_id = 'delivery-evidence'
--     and exists (
--       select 1 from public.branch_memberships m
--       where m.user_id = auth.uid()
--         and m.is_active
--         and m.role in ('owner','admin','cashier')
--     )
--   );
