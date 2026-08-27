-- Cuánta gente quiso pedir durante el prelanzamiento.
--
-- QUÉ MIDE Y QUÉ NO
--
-- Mide toques en el botón "Pedir por WhatsApp" de la pantalla de
-- prelanzamiento. NO mide mensajes enviados: en cuanto la persona sale de la
-- app hacia WhatsApp, el sistema deja de ver lo que hace. Alguien puede tocar
-- el botón, arrepentirse y no escribir nunca.
--
-- Por eso el número de aquí es un techo, no un conteo de pedidos: dice cuánta
-- gente tuvo la intención, que es justo lo que sirve para saber si la app
-- está mandando clientes mientras no se puede pedir desde ella.
--
-- Se guarda una fila por dispositivo, no por toque, para que la cifra
-- responda "cuántas personas" y no "cuántas veces le picaron". El contador
-- de toques queda aparte por si interesa la insistencia.

create table if not exists public.prelaunch_whatsapp_taps (
  branch_id uuid not null references public.branches(id) on delete cascade,
  -- Identificador aleatorio que el navegador genera y guarda. No es un dato
  -- personal: no viene del teléfono ni de la cuenta, y se pierde si la
  -- persona borra los datos del sitio. Sirve para no contar diez veces a
  -- quien tocó diez veces, nada más.
  device_id uuid not null,
  taps integer not null default 1 check (taps > 0),
  first_tap_at timestamptz not null default now(),
  last_tap_at timestamptz not null default now(),
  primary key (branch_id, device_id)
);

create index if not exists prelaunch_taps_branch_idx
  on public.prelaunch_whatsapp_taps(branch_id, first_tap_at desc);

alter table public.prelaunch_whatsapp_taps enable row level security;

-- Nadie sin sesión toca la tabla directamente. El cliente solo puede llamar a
-- la función de abajo, que hace una cosa y nada más. Así no se expone la
-- tabla a escritura libre desde el navegador.
drop policy if exists "staff lee el interes del prelanzamiento" on public.prelaunch_whatsapp_taps;
create policy "staff lee el interes del prelanzamiento" on public.prelaunch_whatsapp_taps
  for select using (
    app_private.is_branch_staff(branch_id, array['owner'::text,'admin'::text,'cashier'::text])
  );

-- Registra el toque. Si el mismo dispositivo vuelve, suma al contador en vez
-- de crear otra fila.
create or replace function public.register_prelaunch_tap(target_branch_id uuid, device uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.prelaunch_whatsapp_taps (branch_id, device_id)
  values (target_branch_id, device)
  on conflict (branch_id, device_id) do update
    set taps = prelaunch_whatsapp_taps.taps + 1,
        last_tap_at = now();
end;
$$;

revoke all on function public.register_prelaunch_tap(uuid, uuid) from public;
grant execute on function public.register_prelaunch_tap(uuid, uuid) to anon, authenticated;
