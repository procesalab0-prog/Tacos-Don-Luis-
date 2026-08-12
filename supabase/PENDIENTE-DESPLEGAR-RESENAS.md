# Pendiente por desplegar: calificaciones de clientes

**Estado:** el código ya está en `main` (versión 2.15.0). Falta aplicarlo en Supabase.
Mientras esto no se haga, el modal de calificación aparece pero al enviar muestra un
error. El resto del sistema funciona normal.

Son dos pasos independientes. Los dos hacen falta.

---

## Paso 1 — Crear la tabla

Va en el **SQL Editor** del panel de Supabase. Es el contenido de
`supabase/migrations/20260812_order_reviews.sql`, se puede pegar tal cual:

```sql
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
  constraint order_reviews_low_rating_needs_comment
    check (rating >= 3 or (comment is not null and length(btrim(comment)) >= 4))
);

create index if not exists order_reviews_branch_idx on public.order_reviews(branch_id);
create index if not exists order_reviews_published_idx
  on public.order_reviews(branch_id, is_published, created_at desc);

alter table public.order_reviews enable row level security;

drop policy if exists "public read published reviews" on public.order_reviews;
create policy "public read published reviews" on public.order_reviews
  for select using (is_published = true);

drop policy if exists "staff read branch reviews" on public.order_reviews;
create policy "staff read branch reviews" on public.order_reviews
  for select using (
    app_private.is_branch_staff(branch_id, array['owner'::text, 'admin'::text, 'cashier'::text])
  );

drop policy if exists "owners publish reviews" on public.order_reviews;
create policy "owners publish reviews" on public.order_reviews
  for update using (
    app_private.is_branch_staff(branch_id, array['owner'::text, 'admin'::text])
  ) with check (
    app_private.is_branch_staff(branch_id, array['owner'::text, 'admin'::text])
  );
```

**Si marca error en `app_private.is_branch_staff`:** esa función auxiliar ya se usa en
otras políticas del proyecto (ver `20260810_restrict_kitchen_role.sql`). Si el nombre
cambió, hay que ajustarlo en las dos políticas de arriba, no inventar una nueva.

---

## Paso 2 — Desplegar la función `submit-review`

Esto **no** se puede hacer desde el SQL Editor: es una Edge Function.

El código fuente está en `supabase/functions/submit-review/index.ts`.

**Opción A — desde el panel de Supabase (sin instalar nada):**
Edge Functions → *Deploy a new function* → nombre exacto: `submit-review` → pegar el
contenido del archivo.

**Opción B — desde la terminal, con el CLI de Supabase:**

```bash
supabase functions deploy submit-review
```

La función usa `SUPABASE_URL` y `SUPABASE_SERVICE_ROLE_KEY`, que Supabase inyecta
sola en las Edge Functions. No hay que configurar variables a mano.

---

## Cómo comprobar que quedó bien

1. Hacer un pedido de prueba en `/pedir/` y llevarlo hasta **entregado** desde el panel.
2. En el portal del cliente debe aparecer el modal **"¿Cómo estuvo tu pedido?"**.
3. Probar con **1 o 2 estrellas sin escribir nada**: no debe dejar enviar.
4. Escribir el comentario y enviar: debe cerrarse y agradecer.
5. En el panel, **Reportes → Calificaciones de clientes**: ahí debe aparecer, con el
   botón *Publicar como testimonio*.
6. Al publicarla, debe salir en la página principal de `/pedir/`, en "Lo que dicen".
   Esa sección permanece oculta mientras no haya ninguna publicada.

---

## Por qué está hecho así

- La calificación se envía con **el mismo token de seguimiento** que ya identifica el
  pedido. Por eso los clientes invitados también pueden opinar sin tener cuenta.
- La regla de *"menos de 3 estrellas obliga a comentar"* está en tres capas: la
  interfaz, la función de servidor y un `check` en la tabla. Así no depende de que el
  navegador se porte bien.
- Las reseñas nacen con `is_published = false`. Nada aparece en la página pública
  hasta que el dueño o el administrador lo autoriza desde el panel.
- Esto sustituye a tres testimonios que estaban **inventados y escritos en el código**.
  No volver a poner reseñas ficticias: además de restar credibilidad, presentarlas como
  opiniones reales es publicidad engañosa.
