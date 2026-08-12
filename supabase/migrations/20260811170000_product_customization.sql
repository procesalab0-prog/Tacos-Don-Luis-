alter table public.products
  add column if not exists customization jsonb not null default '{}'::jsonb;

alter table public.business_settings
  add column if not exists menu_proteins jsonb not null default '["Cabeza","Pastor","Bistec","Chorizo","Costilla","Lengua","Sesos"]'::jsonb;

comment on column public.products.customization is
  'Per-product ordering choices such as variant, protein_options and preparation_options.';

comment on column public.business_settings.menu_proteins is
  'Branch-level editable catalog of proteins used by configurable menu products.';

update public.products p
set customization = jsonb_build_object(
  'variant', case
    when lower(p.name) like '%especial%' then 'special'
    when lower(p.name) like '%clásic%' or lower(p.name) like '%clasic%' then 'classic'
    else 'custom'
  end,
  'protein_options', case
    when lower(p.name) like '%especial%' then '["Lengua","Sesos"]'::jsonb
    when lower(p.name) like '%con queso%' then '["Cabeza","Pastor","Bistec","Chorizo","Costilla","Lengua","Sesos"]'::jsonb
    else '["Cabeza","Pastor","Bistec","Chorizo","Costilla"]'::jsonb
  end,
  'preparation_options', '["Con todo","Solo cebolla","Solo cilantro","Sin cebolla","Sin cilantro","Sin picante","Aparte"]'::jsonb
)
where exists (
  select 1 from public.categories c
  where c.id = p.category_id
    and c.name in ('Quesadillas','Tortas','Tacos light')
)
and coalesce(p.customization, '{}'::jsonb) = '{}'::jsonb;

update public.products p
set customization = jsonb_build_object(
  'variant', 'custom',
  'protein_options', '[]'::jsonb,
  'preparation_options', '["Con todo","Solo cebolla","Solo cilantro","Sin cebolla","Sin cilantro","Sin picante","Aparte"]'::jsonb
)
where exists (
  select 1 from public.categories c
  where c.id = p.category_id and c.name = 'Tacos'
)
and coalesce(p.customization, '{}'::jsonb) = '{}'::jsonb;
