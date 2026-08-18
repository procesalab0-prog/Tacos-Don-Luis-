-- Dueños y administradores pueden editar la configuración del programa de
-- lealtad desde el panel. La lectura pública sigue limitada a reglas activas.
drop policy if exists "staff manage loyalty rules" on public.loyalty_rules;

create policy "staff manage loyalty rules"
on public.loyalty_rules
for all
to authenticated
using (
  app_private.is_branch_staff(branch_id, array['owner', 'admin'])
)
with check (
  app_private.is_branch_staff(branch_id, array['owner', 'admin'])
);

-- Conserva la activación que ya se alcanzó a guardar en business_settings
-- antes de que la actualización de loyalty_rules fuera rechazada por RLS.
update public.loyalty_rules as lr
set config = coalesce(lr.config, '{}'::jsonb) || jsonb_build_object(
  'redemption_enabled', coalesce((bs.payment_methods ->> 'loyalty_points')::boolean, false),
  'redemption_value', coalesce(
    nullif(lr.config ->> 'redemption_value', '')::numeric,
    nullif(lr.config ->> 'redemption_rate', '')::numeric,
    1
  )
)
from public.business_settings as bs
where bs.branch_id = lr.branch_id;
