create or replace function public.driver_attach_evidence(p_assignment_id uuid,p_path text)
returns void language plpgsql security definer set search_path='' as $$
declare a public.driver_assignments; b uuid; u uuid:=auth.uid();
begin
 if u is null then raise exception 'Inicia sesión'; end if;
 select * into a from public.driver_assignments where id=p_assignment_id for update;
 if not found then raise exception 'Entrega no encontrada';end if;
 select branch_id into b from public.orders where id=a.order_id;
 if not ((a.driver_user_id=u and app_private.is_branch_staff(b,array['driver'])) or app_private.is_branch_staff(b,array['owner','admin','cashier'])) then raise exception 'Entrega no autorizada';end if;
 if p_path not like b::text||'/'||u::text||'/'||a.id::text||'-%' or length(p_path)>250 or p_path like '%..%' then raise exception 'Ruta de evidencia inválida'; end if;
 if not exists(select 1 from storage.objects where bucket_id='delivery-evidence' and name=p_path) then raise exception 'Primero sube la foto';end if;
 update public.driver_assignments set evidence_path=p_path where id=a.id;
end $$;
revoke all on function public.driver_attach_evidence(uuid,text) from public,anon;
grant execute on function public.driver_attach_evidence(uuid,text) to authenticated;
