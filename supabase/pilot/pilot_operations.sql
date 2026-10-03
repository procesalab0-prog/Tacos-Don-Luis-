-- Piloto: conservamos los datos de inventario, pero ya no participan en pedidos.
alter table public.orders disable trigger orders_sync_inventory;

create or replace function public.assign_delivery(p_order_id uuid,p_driver_id uuid)
returns public.driver_assignments language plpgsql security definer set search_path='' as $$
declare o public.orders; a public.driver_assignments;
begin
 if auth.uid() is null then raise exception 'Inicia sesión'; end if;
 select * into o from public.orders where id=p_order_id for update;
 if not found or not app_private.is_branch_staff(o.branch_id,array['owner','admin','cashier']) then raise exception 'Pedido no autorizado'; end if;
 if o.fulfillment_type<>'delivery' or o.status not in ('ready','assigned','failed_delivery') then raise exception 'El pedido no está listo para asignar'; end if;
 if not exists(select 1 from public.branch_memberships where branch_id=o.branch_id and user_id=p_driver_id and role='driver' and is_active) then raise exception 'Repartidor no autorizado'; end if;
 select * into a from public.driver_assignments where order_id=o.id for update;
 if found and a.status not in ('assigned','incident','cancelled') then raise exception 'Esta entrega ya está en camino o terminada'; end if;
 insert into public.driver_assignments(order_id,driver_user_id,assigned_by,status)
 values(o.id,p_driver_id,auth.uid(),'assigned') on conflict(order_id) do update
 set driver_user_id=excluded.driver_user_id,assigned_by=excluded.assigned_by,status='assigned',assigned_at=now(),picked_up_at=null,delivered_at=null,incident_note=null,evidence_path=null returning * into a;
 update public.orders set status='assigned',assigned_driver_user_id=p_driver_id where id=o.id;
 return a;
end $$;
revoke all on function public.assign_delivery(uuid,uuid) from public,anon;
grant execute on function public.assign_delivery(uuid,uuid) to authenticated;

create or replace function app_private.guard_order_update()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is not null and app_private.is_branch_staff(old.branch_id,array['kitchen'])
 and not app_private.is_branch_staff(old.branch_id,array['owner','admin','cashier']) then
   if (to_jsonb(new)-array['status','updated_at','promised_at','accepted_at','accepted_by']) is distinct from
      (to_jsonb(old)-array['status','updated_at','promised_at','accepted_at','accepted_by']) then
      raise exception 'Cocina solo puede actualizar la preparación';
   end if;
   if new.status is distinct from old.status and not ((old.status='pending_acceptance' and new.status='confirmed') or (old.status='confirmed' and new.status='preparing') or (old.status='preparing' and new.status='ready')) then
     raise exception 'Cambio de estado no permitido para cocina';
   end if;
 end if;
 if old.scheduled_for is not null and new.status='confirmed' then new.promised_at:=old.scheduled_for; end if;
 if new.status='delivered' and old.status<>'delivered' then
   if new.payment_method<>'cash' and new.payment_status<>'paid' then raise exception 'Confirma el pago antes de entregar'; end if;
   new.completed_at:=coalesce(new.completed_at,now());
   if new.payment_method='cash' then new.payment_status:='paid'; end if;
 end if;
 return new;
end $$;
create trigger orders_guard_pilot before update on public.orders for each row execute function app_private.guard_order_update();

create or replace function app_private.record_order_status()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.status is distinct from old.status then
 insert into public.order_status_history(order_id,from_status,to_status,changed_by,note)
 values(new.id,old.status,new.status,auth.uid(),left(new.cancellation_reason,500));
 end if;
 return new;
end $$;
create trigger orders_history_pilot after update of status on public.orders for each row execute function app_private.record_order_status();

create or replace function app_private.guard_driver_settlement()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_count int; v_cash numeric; v_paid numeric; v_folios text[];
begin
 if tg_op='INSERT' then
   if new.status<>'pending' or new.settled_at is not null or new.settled_by is not null then raise exception 'La liquidación debe iniciar pendiente'; end if;
   if auth.uid() is not null and not (new.driver_user_id=auth.uid() and app_private.is_branch_staff(new.branch_id,array['driver'])) and not app_private.is_branch_staff(new.branch_id,array['owner','admin','cashier']) then raise exception 'Liquidación no autorizada'; end if;
   perform pg_advisory_xact_lock(hashtextextended(new.driver_user_id::text,71));
   select count(*),coalesce(sum(o.total) filter(where o.payment_method='cash'),0),coalesce(sum(o.total) filter(where o.payment_method<>'cash' and o.payment_status='paid'),0),array_agg('DL-'||o.folio order by o.folio)
   into v_count,v_cash,v_paid,v_folios from public.driver_assignments a join public.orders o on o.id=a.order_id
   where a.driver_user_id=new.driver_user_id and o.branch_id=new.branch_id and a.status='delivered' and o.status='delivered' and not o.is_demo
   and not exists(select 1 from public.driver_settlements s where s.driver_user_id=new.driver_user_id and s.branch_id=new.branch_id and s.status in ('pending','settled') and ('DL-'||o.folio)=any(s.folios));
   if v_count=0 then raise exception 'No hay entregas pendientes de liquidar'; end if;
   new.deliveries_count:=v_count;new.cash_amount:=v_cash;new.paid_amount:=v_paid;new.folios:=v_folios;
 else
   if (to_jsonb(new)-array['status','settled_at','settled_by','note']) is distinct from (to_jsonb(old)-array['status','settled_at','settled_by','note']) then raise exception 'No se pueden cambiar los importes de la liquidación'; end if;
   if old.status<>'pending' and new is distinct from old then raise exception 'La liquidación ya está cerrada'; end if;
   if new.status='settled' then new.settled_at:=now();new.settled_by:=auth.uid(); end if;
 end if;
 return new;
end $$;
create trigger driver_settlements_guard_pilot before insert or update on public.driver_settlements for each row execute function app_private.guard_driver_settlement();

create or replace function app_private.guard_cash_shift()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_sales numeric;v_settlements numeric;v_moves numeric;
begin
 perform pg_advisory_xact_lock(hashtextextended(new.branch_id::text,72));
 if tg_op='INSERT' then
   if new.status<>'open' then raise exception 'La caja debe iniciar abierta'; end if;
   if exists(select 1 from public.cash_shifts where branch_id=new.branch_id and status='open') then raise exception 'Ya hay una caja abierta'; end if;
   new.opened_at:=now();new.opened_by:=auth.uid();new.closed_at:=null;new.closed_by:=null;new.expected_cash:=null;new.counted_cash:=null;
 else
   if old.status='closed' then raise exception 'El corte ya está cerrado'; end if;
   if (to_jsonb(new)-array['status','closed_at','closed_by','expected_cash','counted_cash','notes']) is distinct from (to_jsonb(old)-array['status','closed_at','closed_by','expected_cash','counted_cash','notes']) then raise exception 'No se puede cambiar la apertura'; end if;
   if new.status='closed' then
     new.closed_at:=now();new.closed_by:=auth.uid();
     if new.counted_cash is null or new.counted_cash<0 then raise exception 'Escribe el efectivo contado'; end if;
     select coalesce(sum(total),0) into v_sales from public.orders where branch_id=old.branch_id and fulfillment_type<>'delivery' and status='delivered' and payment_method='cash' and payment_status='paid' and not is_demo and completed_at>=old.opened_at and completed_at<=new.closed_at;
     select coalesce(sum(cash_amount),0) into v_settlements from public.driver_settlements where branch_id=old.branch_id and status='settled' and settled_at>=old.opened_at and settled_at<=new.closed_at;
     select coalesce(sum(case when movement_type in ('expense','refund') then -amount else amount end),0) into v_moves from public.cash_movements where cash_shift_id=old.id and payment_method='cash';
     new.expected_cash:=old.opening_amount+v_sales+v_settlements+v_moves;
   end if;
 end if;
 return new;
end $$;
create trigger cash_shifts_guard_pilot before insert or update on public.cash_shifts for each row execute function app_private.guard_cash_shift();

revoke all on function app_private.guard_order_update(),app_private.record_order_status(),app_private.guard_driver_settlement(),app_private.guard_cash_shift() from public,anon,authenticated;
