-- Pago parcial o total con puntos, validado y aplicado dentro de Postgres.
-- La función sólo puede ejecutarla service_role desde create-guest-order.

alter table public.orders
  add column if not exists loyalty_points_redeemed integer not null default 0
  check (loyalty_points_redeemed >= 0);

alter table public.orders drop constraint if exists orders_payment_method_check;
alter table public.orders add constraint orders_payment_method_check
  check (payment_method = any (array[
    'cash'::text,
    'transfer'::text,
    'card_present'::text,
    'clip_simulated'::text,
    'loyalty_points'::text
  ]));

create index if not exists order_reviews_customer_id_idx
  on public.order_reviews(customer_id)
  where customer_id is not null;

drop function if exists public.apply_loyalty_points_to_order(uuid, uuid, integer);
create function public.apply_loyalty_points_to_order(
  p_order_id uuid,
  p_customer_id uuid,
  p_requested_points integer
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.orders%rowtype;
  v_settings public.business_settings%rowtype;
  v_rule public.loyalty_rules%rowtype;
  v_account public.loyalty_accounts%rowtype;
  v_value numeric;
  v_points integer;
  v_discount numeric;
  v_total numeric;
begin
  if p_requested_points is null or p_requested_points <= 0 then
    raise exception 'La cantidad de puntos debe ser mayor a cero';
  end if;

  select * into v_order
  from public.orders
  where id = p_order_id and customer_id = p_customer_id
  for update;
  if not found then raise exception 'Pedido o cliente inválido'; end if;
  if v_order.status <> 'pending_acceptance' then raise exception 'El pedido ya no admite cambios'; end if;
  if v_order.loyalty_points_redeemed > 0 then raise exception 'Los puntos ya fueron aplicados'; end if;

  select * into v_settings from public.business_settings where branch_id = v_order.branch_id;
  select * into v_rule from public.loyalty_rules
    where branch_id = v_order.branch_id and is_active = true
    order by name limit 1;
  if not found or v_settings.loyalty_enabled is not true then
    raise exception 'El programa de lealtad no está disponible';
  end if;
  if coalesce((v_settings.payment_methods ->> 'loyalty_points')::boolean, false) is not true then
    raise exception 'El pago con puntos está desactivado';
  end if;
  if coalesce((v_rule.config ->> 'redemption_enabled')::boolean, false) is not true then
    raise exception 'El canje de puntos está desactivado';
  end if;

  v_value := coalesce((v_rule.config ->> 'redemption_value')::numeric, 0);
  if v_value <= 0 then raise exception 'El valor de los puntos no está configurado'; end if;

  insert into public.loyalty_accounts(customer_id)
  values (p_customer_id)
  on conflict(customer_id) do nothing;
  select * into v_account from public.loyalty_accounts
    where customer_id = p_customer_id for update;

  v_points := least(
    p_requested_points,
    v_account.points_balance,
    ceil(v_order.total / v_value)::integer
  );
  if v_points <= 0 then raise exception 'No tienes puntos disponibles'; end if;

  v_discount := least(v_order.total, round(v_points * v_value, 2));
  v_total := greatest(0, v_order.total - v_discount);

  update public.loyalty_accounts
    set points_balance = points_balance - v_points, updated_at = now()
    where id = v_account.id;
  insert into public.loyalty_movements(
    loyalty_account_id, order_id, movement_type, points, description
  ) values (
    v_account.id, v_order.id, 'redeem', -v_points,
    'Pago con puntos · pedido DL-' || v_order.folio
  );
  update public.orders
    set loyalty_points_redeemed = v_points,
        loyalty_discount = v_discount,
        discount_total = discount_total + v_discount,
        total = v_total,
        payment_method = case when v_total = 0 then 'loyalty_points' else payment_method end,
        payment_status = case when v_total = 0 then 'paid' else payment_status end,
        updated_at = now()
    where id = v_order.id;

  return jsonb_build_object(
    'points_used', v_points,
    'discount', v_discount,
    'total', v_total,
    'paid_with_points', v_total = 0
  );
end;
$$;

revoke all on function public.apply_loyalty_points_to_order(uuid, uuid, integer) from public, anon, authenticated;
grant execute on function public.apply_loyalty_points_to_order(uuid, uuid, integer) to service_role;

-- Si el negocio rechaza o cancela un pedido pagado con puntos, se regresan
-- una sola vez. El movimiento de reversa conserva un historial auditable.
create or replace function public.restore_order_loyalty_points()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_account_id uuid;
  v_points integer;
  v_inserted bigint;
begin
  if new.status not in ('rejected', 'cancelled')
     or old.status in ('rejected', 'cancelled') then
    return new;
  end if;

  select loyalty_account_id, -points
    into v_account_id, v_points
  from public.loyalty_movements
  where order_id = new.id and movement_type = 'redeem'
  limit 1;

  if v_account_id is null or coalesce(v_points, 0) <= 0 then return new; end if;

  insert into public.loyalty_movements(
    loyalty_account_id, order_id, movement_type, points, description
  ) values (
    v_account_id, new.id, 'reversal', v_points,
    'Devolución de puntos · pedido DL-' || new.folio
  )
  on conflict(order_id, movement_type) where order_id is not null do nothing
  returning id into v_inserted;

  if v_inserted is not null then
    update public.loyalty_accounts
      set points_balance = points_balance + v_points, updated_at = now()
      where id = v_account_id;
  end if;
  return new;
end;
$$;

revoke all on function public.restore_order_loyalty_points() from public, anon, authenticated;

drop trigger if exists restore_order_loyalty_points_trigger on public.orders;
create trigger restore_order_loyalty_points_trigger
after update of status on public.orders
for each row execute function public.restore_order_loyalty_points();

-- Evita recalcular auth.uid() por cada fila en las políticas nuevas de liquidaciones.
drop policy if exists "driver crea su liquidacion" on public.driver_settlements;
create policy "driver crea su liquidacion" on public.driver_settlements
  for insert to authenticated
  with check (driver_user_id = (select auth.uid()));

drop policy if exists "driver lee sus liquidaciones" on public.driver_settlements;
create policy "driver lee sus liquidaciones" on public.driver_settlements
  for select to authenticated
  using (driver_user_id = (select auth.uid()));
