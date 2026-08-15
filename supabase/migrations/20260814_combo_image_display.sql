-- Preferencias de encuadre para la foto de cada combo.
alter table public.combos
  add column if not exists image_fit text not null default 'cover'
    check (image_fit in ('cover','contain')),
  add column if not exists image_position text not null default 'center'
    check (image_position in ('top','center','bottom'));

comment on column public.combos.image_fit is
  'cover llena el espacio con recorte; contain muestra la fotografía completa.';
comment on column public.combos.image_position is
  'Zona que se conserva al recortar la imagen: top, center o bottom.';
