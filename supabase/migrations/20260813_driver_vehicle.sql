-- Datos del vehículo del repartidor, para que el cliente sepa quién le va a
-- llegar y con qué placas. Se piden una sola vez, la primera vez que el
-- repartidor entra a su portal.

alter table public.driver_status
  add column if not exists vehicle_type text,
  add column if not exists vehicle_plate text,
  add column if not exists vehicle_color text;

comment on column public.driver_status.vehicle_type is
  'Tipo de vehículo con el que reparte: moto, bicicleta, automóvil.';
comment on column public.driver_status.vehicle_plate is
  'Placas del vehículo. Se muestran al cliente para que identifique la entrega.';
comment on column public.driver_status.vehicle_color is
  'Color del vehículo, para reconocerlo al llegar.';
