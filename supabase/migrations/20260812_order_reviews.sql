-- Reseñas que deja el cliente cuando su pedido ya fue entregado.
-- Sustituyen a los testimonios que estaban escritos a mano en el código:
-- solo se muestran en la página pública las que el negocio marque como publicadas.

create table if not exists public.order_reviews (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references public.orders(id) on delete cascade,
  branch_id uuid not null references public.branches(id) on delete cascade,
  customer_id uuid references public.customers(id) on delete set null,
  rating smallint not null check (rating between 1 and 5),
  comment text,
  display_name text,
  is_published boolean not null default false,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  -- Una calificación baja obliga a explicar qué pasó; así el negocio sabe
  -- qué corregir en vez de recibir solo una estrella sin contexto.
  constraint order_reviews_low_rating_needs_comment
    check (rating >= 3 or (comment is not null and length(btrim(comment)) >= 4))
);

create index if not exists order_reviews_branch_idx on public.order_reviews(branch_id);
create index if not exists order_reviews_published_idx
  on public.order_reviews(branch_id, is_published, created_at desc);

alter table public.order_reviews enable row level security;

-- Cualquiera puede leer las reseñas ya publicadas: son los testimonios del sitio.
drop policy if exists "public read published reviews" on public.order_reviews;
create policy "public read published reviews" on public.order_reviews
  for select using (is_published = true);

-- El personal de la sucursal ve todas las reseñas, publicadas o no.
drop policy if exists "staff read branch reviews" on public.order_reviews;
create policy "staff read branch reviews" on public.order_reviews
  for select using (
    app_private.is_branch_staff(branch_id, array['owner'::text, 'admin'::text, 'cashier'::text])
  );

-- Solo dueño y administrador deciden qué se publica.
drop policy if exists "owners publish reviews" on public.order_reviews;
create policy "owners publish reviews" on public.order_reviews
  for update using (
    app_private.is_branch_staff(branch_id, array['owner'::text, 'admin'::text])
  ) with check (
    app_private.is_branch_staff(branch_id, array['owner'::text, 'admin'::text])
  );

comment on table public.order_reviews is
  'Calificaciones de clientes por pedido entregado. Solo las marcadas como publicadas se muestran en la página pública.';
