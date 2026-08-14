drop policy if exists "driver uploads branch delivery evidence" on storage.objects;
drop policy if exists "staff uploads branch delivery evidence" on storage.objects;

create policy "staff uploads branch delivery evidence"
on storage.objects for insert to authenticated
with check (
  bucket_id='delivery-evidence'
  and (storage.foldername(name))[1] in (
    select bm.branch_id::text
    from public.branch_memberships bm
    where bm.user_id=(select auth.uid())
      and bm.role in ('driver','owner','admin','cashier')
      and bm.is_active
  )
  and (storage.foldername(name))[2]=(select auth.uid())::text
);
