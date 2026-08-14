create or replace function public.admin_list_active_accounts(target_branch_id uuid)
returns table (id uuid, email text, full_name text, phone text, created_at timestamptz, last_sign_in_at timestamptz, orders_count bigint)
language sql security definer set search_path = public, auth
as $$
  select u.id, u.email::text, p.full_name, p.phone, u.created_at, u.last_sign_in_at,
         (select count(*) from public.orders o where o.customer_id=u.id and o.branch_id=target_branch_id)
  from auth.users u left join public.profiles p on p.id=u.id
  where u.deleted_at is null and (u.banned_until is null or u.banned_until < now())
    and exists (select 1 from public.branch_memberships bm where bm.user_id=auth.uid() and bm.branch_id=target_branch_id and bm.role in ('owner','admin') and bm.is_active)
  order by u.created_at desc;
$$;
revoke all on function public.admin_list_active_accounts(uuid) from public, anon;
grant execute on function public.admin_list_active_accounts(uuid) to authenticated;

insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('delivery-evidence','delivery-evidence',false,5242880,array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

create policy "driver uploads branch delivery evidence" on storage.objects for insert to authenticated
with check (bucket_id='delivery-evidence' and (storage.foldername(name))[1] in (select bm.branch_id::text from public.branch_memberships bm where bm.user_id=auth.uid() and bm.role='driver' and bm.is_active) and (storage.foldername(name))[2]=auth.uid()::text);

create policy "staff reads branch delivery evidence" on storage.objects for select to authenticated
using (bucket_id='delivery-evidence' and (((storage.foldername(name))[2]=auth.uid()::text) or (storage.foldername(name))[1] in (select bm.branch_id::text from public.branch_memberships bm where bm.user_id=auth.uid() and bm.role in ('owner','admin','cashier') and bm.is_active)));
