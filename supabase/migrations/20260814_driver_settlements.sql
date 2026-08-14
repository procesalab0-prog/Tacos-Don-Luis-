-- Solicitudes de liquidación de turno de los repartidores.
--
-- Antes el repartidor mandaba su corte por WhatsApp y en administración no
-- quedaba registro de nada: caja no sabía quién había pedido liquidar ni
-- cuánto efectivo traía. Ahora la solicitud es una fila que caja ve y cierra.

create table if not exists public.driver_settlements (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches(id) on delete cascade,
  driver_user_id uuid not null references auth.users(id) on delete cascade,
  requested_at timestamptz not null default now(),
  deliveries_count integer not null default 0 check (deliveries_count >= 0),
  cash_amount numeric(10,2) not null default 0 check (cash_amount >= 0),
  paid_amount numeric(10,2) not null default 0 check (paid_amount >= 0),
  folios text[] not null default '{}',
  status text not null default 'pending'
    check (status in ('pending','settled','cancelled')),
  settled_at timestamptz,
  settled_by uuid references auth.users(id),
  note text
);

create index if not exists driver_settlements_branch_idx
  on public.driver_settlements(branch_id, status, requested_at desc);
create index if not exists driver_settlements_driver_idx
  on public.driver_settlements(driver_user_id, requested_at desc);

-- Un repartidor no puede tener dos solicitudes abiertas a la vez: si toca el
-- botón dos veces, la segunda no entra en vez de duplicar el corte.
create unique index if not exists driver_settlements_una_abierta
  on public.driver_settlements(driver_user_id)
  where status = 'pending';

alter table public.driver_settlements enable row level security;

drop policy if exists "driver crea su liquidacion" on public.driver_settlements;
create policy "driver crea su liquidacion" on public.driver_settlements
  for insert with check (driver_user_id = auth.uid());

drop policy if exists "driver lee sus liquidaciones" on public.driver_settlements;
create policy "driver lee sus liquidaciones" on public.driver_settlements
  for select using (driver_user_id = auth.uid());

drop policy if exists "staff lee liquidaciones" on public.driver_settlements;
create policy "staff lee liquidaciones" on public.driver_settlements
  for select using (
    app_private.is_branch_staff(branch_id, array['owner'::text,'admin'::text,'cashier'::text])
  );

-- Cerrar una liquidación mueve dinero: se limita a quien maneja la caja.
drop policy if exists "staff cierra liquidaciones" on public.driver_settlements;
create policy "staff cierra liquidaciones" on public.driver_settlements
  for update using (
    app_private.is_branch_staff(branch_id, array['owner'::text,'admin'::text,'cashier'::text])
  ) with check (
    app_private.is_branch_staff(branch_id, array['owner'::text,'admin'::text,'cashier'::text])
  );
