-- Fotos públicas administrables para productos, promociones, novedades y combos.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('menu-media','menu-media',true,5242880,array['image/jpeg','image/png','image/webp'])
on conflict (id) do update
  set public=true,
      file_size_limit=excluded.file_size_limit,
      allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists "staff uploads menu media" on storage.objects;
create policy "staff uploads menu media" on storage.objects
  for insert to authenticated with check (
    bucket_id='menu-media'
    and (storage.foldername(name))[1] in (
      select bm.branch_id::text
      from public.branch_memberships bm
      where bm.user_id=(select auth.uid())
        and bm.role in ('owner','admin')
        and bm.is_active
    )
  );

drop policy if exists "staff deletes menu media" on storage.objects;
create policy "staff deletes menu media" on storage.objects
  for delete to authenticated using (
    bucket_id='menu-media'
    and (storage.foldername(name))[1] in (
      select bm.branch_id::text
      from public.branch_memberships bm
      where bm.user_id=(select auth.uid())
        and bm.role in ('owner','admin')
        and bm.is_active
    )
  );
