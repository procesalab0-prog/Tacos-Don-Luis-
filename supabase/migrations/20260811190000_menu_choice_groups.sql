update public.products p
set customization = coalesce(p.customization, '{}'::jsonb) || jsonb_build_object(
  'preparation_options', '["Con todo","Solo cebolla","Solo cilantro","Sin cebolla","Sin cilantro","Sin picante"]'::jsonb,
  'sauce_options', '["Salsa roja","Salsa verde"]'::jsonb,
  'aside_options', '["Cebolla aparte","Cilantro aparte","Salsa roja aparte","Salsa verde aparte","Todo aparte"]'::jsonb
)
where exists (
  select 1 from public.categories c
  where c.id = p.category_id and c.name <> 'Bebidas'
);

update public.products p
set customization = coalesce(p.customization, '{}'::jsonb) || jsonb_build_object(
  'preparation_options', '[]'::jsonb,
  'sauce_options', '[]'::jsonb,
  'aside_options', '[]'::jsonb,
  'flavor_options', '["Jamaica","Horchata","Lima"]'::jsonb
),
description = 'Elige Jamaica, Horchata o Lima'
where exists (
  select 1 from public.categories c
  where c.id = p.category_id and c.name = 'Bebidas'
)
and lower(p.name) like '%agua%';

update public.products p
set customization = coalesce(p.customization, '{}'::jsonb) || jsonb_build_object(
  'preparation_options', '[]'::jsonb,
  'sauce_options', '[]'::jsonb,
  'aside_options', '[]'::jsonb,
  'flavor_options', '[]'::jsonb
),
description = 'Coca-Cola'
where exists (
  select 1 from public.categories c
  where c.id = p.category_id and c.name = 'Bebidas'
)
and lower(p.name) like '%refresco%';
