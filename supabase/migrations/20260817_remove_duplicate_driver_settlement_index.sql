-- Conservamos driver_settlements_una_abierta, que es el índice canónico del
-- repositorio, y retiramos su duplicado exacto detectado por el asesor.
drop index if exists public.driver_settlements_one_pending;
