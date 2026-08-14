create index if not exists driver_settlements_settled_by_idx
on public.driver_settlements(settled_by)
where settled_by is not null;
