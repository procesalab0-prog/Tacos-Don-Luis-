alter table public.business_settings
  add column if not exists weekly_schedule jsonb,
  add column if not exists payment_methods jsonb not null default '{"cash":true,"transfer":true,"card_present":true}'::jsonb;

comment on column public.business_settings.weekly_schedule is
  'Weekly opening schedule in America/Mexico_City. Keys: mon..sun; values: enabled, open and close.';

comment on column public.business_settings.payment_methods is
  'Payment methods offered at checkout. Supported keys: cash, transfer and card_present.';
