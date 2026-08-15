-- Asigna a cada producto su fotografía.
--
-- Las imágenes viven en el repositorio y se sirven desde el mismo dominio, así
-- que basta con guardar la ruta. No hace falta subirlas a Supabase.
--
-- CÓMO USARLO
--   1. Corre el bloque de REVISIÓN y confirma que cada producto quedó con la
--      foto que le toca. Si alguno sale mal o vacío, ajusta ahí mismo el
--      patrón antes de continuar.
--   2. Corre el bloque de APLICACIÓN.
--
-- Los patrones buscan por nombre porque los productos de esta sucursal no
-- tienen una clave estable que se pueda usar desde fuera. Por eso la revisión
-- previa importa: si algún producto se llama distinto a lo esperado, se queda
-- sin foto en vez de recibir una equivocada.

-- ─────────────────────────── REVISIÓN ───────────────────────────
with fotos as (
  select p.id, p.name, c.name as categoria,
    case
      -- Tacos: cada carne tiene la suya
      when c.name ilike '%light%'      and p.name ilike '%especial%' then 'light_especial'
      when c.name ilike '%light%'                                     then 'light_clasico'
      when c.name ilike '%quesadilla%' and p.name ilike '%especial%' then 'quesadilla_especial'
      when c.name ilike '%quesadilla%'                                then 'quesadilla_clasica'
      when c.name ilike '%torta%'      and p.name ilike '%especial%' then 'torta_especial'
      when c.name ilike '%torta%'                                     then 'torta_clasica'
      when c.name ilike '%taco%'       and p.name ilike '%arrachera%' then 't_arrachera'
      when c.name ilike '%taco%'       and p.name ilike '%pastor%'    then 't_pastor'
      when c.name ilike '%taco%'       and p.name ilike '%bistec%'    then 't_bistec'
      when c.name ilike '%taco%'       and p.name ilike '%cabeza%'    then 't_cabeza'
      when c.name ilike '%taco%'       and p.name ilike '%chorizo%'   then 't_chorizo'
      when c.name ilike '%taco%'       and p.name ilike '%lengua%'    then 't_lengua'
      when c.name ilike '%taco%'       and p.name ilike '%seso%'      then 't_sesos'
      -- Bebidas
      when p.name ilike '%refresco%' or p.name ilike '%coca%'         then 'refresco'
      when p.name ilike '%agua%' and (p.name ilike '%litro%' and p.name not ilike '%medio%' and p.name not ilike '%½%' and p.name not ilike '%1/2%') then 'agua_litro'
      when p.name ilike '%agua%'                                      then 'agua_medio'
    end as archivo
  from public.products p
  join public.categories c on c.id = p.category_id
  where p.branch_id = (select id from public.branches where slug = 'punto-canada')
)
select categoria, name,
       coalesce('/assets/productos/' || archivo || '.jpg', '⚠ SIN FOTO') as image_url
from fotos
order by (archivo is null) desc, categoria, name;

-- ────────────────────────── APLICACIÓN ──────────────────────────
-- Descomenta y corre solo después de revisar el resultado de arriba.
--
-- with fotos as ( ...misma consulta de arriba... )
-- update public.products p
--    set image_url = '/assets/productos/' || f.archivo || '.jpg'
--   from fotos f
--  where p.id = f.id
--    and f.archivo is not null;

-- Para dejarlo en un solo paso, esta es la versión completa:
/*
with fotos as (
  select p.id,
    case
      when c.name ilike '%light%'      and p.name ilike '%especial%' then 'light_especial'
      when c.name ilike '%light%'                                     then 'light_clasico'
      when c.name ilike '%quesadilla%' and p.name ilike '%especial%' then 'quesadilla_especial'
      when c.name ilike '%quesadilla%'                                then 'quesadilla_clasica'
      when c.name ilike '%torta%'      and p.name ilike '%especial%' then 'torta_especial'
      when c.name ilike '%torta%'                                     then 'torta_clasica'
      when c.name ilike '%taco%'       and p.name ilike '%arrachera%' then 't_arrachera'
      when c.name ilike '%taco%'       and p.name ilike '%pastor%'    then 't_pastor'
      when c.name ilike '%taco%'       and p.name ilike '%bistec%'    then 't_bistec'
      when c.name ilike '%taco%'       and p.name ilike '%cabeza%'    then 't_cabeza'
      when c.name ilike '%taco%'       and p.name ilike '%chorizo%'   then 't_chorizo'
      when c.name ilike '%taco%'       and p.name ilike '%lengua%'    then 't_lengua'
      when c.name ilike '%taco%'       and p.name ilike '%seso%'      then 't_sesos'
      when p.name ilike '%refresco%' or p.name ilike '%coca%'         then 'refresco'
      when p.name ilike '%agua%' and (p.name ilike '%litro%' and p.name not ilike '%medio%' and p.name not ilike '%½%' and p.name not ilike '%1/2%') then 'agua_litro'
      when p.name ilike '%agua%'                                      then 'agua_medio'
    end as archivo
  from public.products p
  join public.categories c on c.id = p.category_id
  where p.branch_id = (select id from public.branches where slug = 'punto-canada')
)
update public.products p
   set image_url = '/assets/productos/' || f.archivo || '.jpg'
  from fotos f
 where p.id = f.id
   and f.archivo is not null;
*/
