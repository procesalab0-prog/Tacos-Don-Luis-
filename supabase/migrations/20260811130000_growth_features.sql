-- Growth features: editable home content, combos, loyalty rewards and referrals.

create table if not exists public.marketing_content (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches(id) on delete cascade,
  content_type text not null check (content_type in ('daily_promo','news')),
  title text not null,
  description text not null default '',
  image_url text,
  product_id uuid references public.products(id) on delete set null,
  badge text,
  starts_at timestamptz,
  ends_at timestamptz,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists marketing_content_public_idx on public.marketing_content(branch_id,content_type,is_active,sort_order);

create table if not exists public.combos (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches(id) on delete cascade,
  name text not null,
  description text not null default '',
  image_url text,
  price numeric(12,2) not null check (price >= 0),
  components jsonb not null default '[]'::jsonb,
  app_exclusive boolean not null default false,
  starts_at timestamptz,
  ends_at timestamptz,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists combos_public_idx on public.combos(branch_id,is_active,sort_order);

create table if not exists public.product_sales_stats (
  branch_id uuid not null references public.branches(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  units_sold bigint not null default 0 check (units_sold >= 0),
  order_count bigint not null default 0 check (order_count >= 0),
  updated_at timestamptz not null default now(),
  primary key(branch_id,product_id)
);

create table if not exists public.loyalty_rewards (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches(id) on delete cascade,
  name text not null,
  description text not null default '',
  reward_type text not null check (reward_type in ('points','purchase_count','buy_x_get_y')),
  points_cost integer not null default 0 check (points_cost >= 0),
  required_purchases integer not null default 0 check (required_purchases >= 0),
  required_product_quantity integer not null default 0 check (required_product_quantity >= 0),
  reward_product_id uuid references public.products(id) on delete set null,
  reward_quantity integer not null default 1 check (reward_quantity > 0),
  is_active boolean not null default true,
  sort_order integer not null default 0,
  config jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.loyalty_redemptions (
  id uuid primary key default gen_random_uuid(),
  loyalty_account_id uuid not null references public.loyalty_accounts(id) on delete cascade,
  reward_id uuid not null references public.loyalty_rewards(id),
  points_spent integer not null default 0,
  status text not null default 'issued' check (status in ('issued','applied','cancelled')),
  redemption_code text not null unique,
  created_at timestamptz not null default now(),
  applied_at timestamptz
);

create table if not exists public.referral_codes (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches(id) on delete cascade,
  customer_id uuid not null references public.customers(id) on delete cascade,
  code text not null unique,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique(branch_id,customer_id)
);

create table if not exists public.referrals (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches(id) on delete cascade,
  referral_code_id uuid not null references public.referral_codes(id),
  referred_customer_id uuid not null references public.customers(id) on delete cascade,
  status text not null default 'registered' check (status in ('registered','qualified','rewarded')),
  reward_points integer not null default 0,
  created_at timestamptz not null default now(),
  qualified_at timestamptz,
  unique(branch_id,referred_customer_id)
);

alter table public.marketing_content enable row level security;
alter table public.combos enable row level security;
alter table public.product_sales_stats enable row level security;
alter table public.loyalty_rewards enable row level security;
alter table public.loyalty_redemptions enable row level security;
alter table public.referral_codes enable row level security;
alter table public.referrals enable row level security;

create policy "public read active marketing" on public.marketing_content for select to anon,authenticated using (is_active and (starts_at is null or starts_at<=now()) and (ends_at is null or ends_at>=now()));
create policy "staff manage marketing" on public.marketing_content for all to authenticated using (app_private.is_branch_staff(branch_id,array['owner','admin'])) with check (app_private.is_branch_staff(branch_id,array['owner','admin']));
create policy "public read active combos" on public.combos for select to anon,authenticated using (is_active and (starts_at is null or starts_at<=now()) and (ends_at is null or ends_at>=now()));
create policy "staff manage combos" on public.combos for all to authenticated using (app_private.is_branch_staff(branch_id,array['owner','admin'])) with check (app_private.is_branch_staff(branch_id,array['owner','admin']));
create policy "public read sales ranking" on public.product_sales_stats for select to anon,authenticated using (true);
create policy "public read active rewards" on public.loyalty_rewards for select to anon,authenticated using (is_active);
create policy "staff manage rewards" on public.loyalty_rewards for all to authenticated using (app_private.is_branch_staff(branch_id,array['owner','admin'])) with check (app_private.is_branch_staff(branch_id,array['owner','admin']));
create policy "customer read own redemptions" on public.loyalty_redemptions for select to authenticated using (exists(select 1 from public.loyalty_accounts a join public.customers c on c.id=a.customer_id where a.id=loyalty_account_id and c.user_id=(select auth.uid())));
create policy "staff read redemptions" on public.loyalty_redemptions for select to authenticated using (exists(select 1 from public.loyalty_rewards r where r.id=reward_id and app_private.is_branch_staff(r.branch_id,null)));
create policy "customer read own referral code" on public.referral_codes for select to authenticated using (exists(select 1 from public.customers c where c.id=customer_id and c.user_id=(select auth.uid())));
create policy "customer read own referrals" on public.referrals for select to authenticated using (exists(select 1 from public.referral_codes rc join public.customers c on c.id=rc.customer_id where rc.id=referral_code_id and c.user_id=(select auth.uid())) or exists(select 1 from public.customers c where c.id=referred_customer_id and c.user_id=(select auth.uid())));

create or replace function public.record_product_sales() returns trigger language plpgsql security definer set search_path='' as $$
begin
  if new.status='delivered' and old.status is distinct from 'delivered' then
    insert into public.product_sales_stats(branch_id,product_id,units_sold,order_count)
    select new.branch_id,oi.product_id,sum(oi.quantity),count(distinct oi.order_id)
    from public.order_items oi where oi.order_id=new.id and oi.product_id is not null group by oi.product_id
    on conflict(branch_id,product_id) do update set units_sold=public.product_sales_stats.units_sold+excluded.units_sold,order_count=public.product_sales_stats.order_count+excluded.order_count,updated_at=now();
  end if;
  return new;
end $$;
drop trigger if exists orders_record_product_sales on public.orders;
create trigger orders_record_product_sales after update of status on public.orders for each row execute function public.record_product_sales();

create or replace function public.redeem_loyalty_reward(p_reward_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_customer uuid; v_account public.loyalty_accounts%rowtype; v_reward public.loyalty_rewards%rowtype; v_purchases integer; v_used integer; v_units integer; v_code text; v_redemption uuid;
begin
  select id into v_customer from public.customers where user_id=(select auth.uid());
  if v_customer is null then raise exception 'Necesitas iniciar sesión'; end if;
  select * into v_reward from public.loyalty_rewards where id=p_reward_id and is_active=true;
  if not found then raise exception 'Premio no disponible'; end if;
  insert into public.loyalty_accounts(customer_id) values(v_customer) on conflict(customer_id) do nothing;
  select * into v_account from public.loyalty_accounts where customer_id=v_customer for update;
  if v_reward.reward_type='points' and v_account.points_balance<v_reward.points_cost then raise exception 'Puntos insuficientes'; end if;
  if v_reward.reward_type='purchase_count' then
    select count(*) into v_purchases from public.orders where customer_id=v_customer and branch_id=v_reward.branch_id and status='delivered';
    select count(*) into v_used from public.loyalty_redemptions lr where lr.loyalty_account_id=v_account.id and lr.reward_id=v_reward.id and lr.status<>'cancelled';
    if v_purchases < v_reward.required_purchases*(v_used+1) then raise exception 'Aún no completas las compras necesarias'; end if;
  end if;
  if v_reward.reward_type='buy_x_get_y' then
    select coalesce(sum(oi.quantity),0) into v_units from public.orders o join public.order_items oi on oi.order_id=o.id where o.customer_id=v_customer and o.branch_id=v_reward.branch_id and o.status='delivered' and (v_reward.reward_product_id is null or oi.product_id=v_reward.reward_product_id);
    select count(*) into v_used from public.loyalty_redemptions lr where lr.loyalty_account_id=v_account.id and lr.reward_id=v_reward.id and lr.status<>'cancelled';
    if v_units < v_reward.required_product_quantity*(v_used+1) then raise exception 'Aún no completas las compras necesarias'; end if;
  end if;
  v_code:=upper(substr(replace(gen_random_uuid()::text,'-',''),1,10));
  insert into public.loyalty_redemptions(loyalty_account_id,reward_id,points_spent,redemption_code) values(v_account.id,v_reward.id,case when v_reward.reward_type='points' then v_reward.points_cost else 0 end,v_code) returning id into v_redemption;
  if v_reward.reward_type='points' and v_reward.points_cost>0 then
    update public.loyalty_accounts set points_balance=points_balance-v_reward.points_cost,updated_at=now() where id=v_account.id;
    insert into public.loyalty_movements(loyalty_account_id,movement_type,points,description) values(v_account.id,'redeem',-v_reward.points_cost,'Canje: '||v_reward.name||' · '||v_code);
  end if;
  return jsonb_build_object('id',v_redemption,'code',v_code,'reward',v_reward.name,'points_spent',case when v_reward.reward_type='points' then v_reward.points_cost else 0 end);
end $$;
grant execute on function public.redeem_loyalty_reward(uuid) to authenticated;

create or replace function public.ensure_referral_code(p_branch_id uuid) returns text language plpgsql security definer set search_path='' as $$
declare v_customer uuid; v_code text;
begin
  select id into v_customer from public.customers where user_id=(select auth.uid());
  if v_customer is null then raise exception 'Necesitas iniciar sesión'; end if;
  select code into v_code from public.referral_codes where branch_id=p_branch_id and customer_id=v_customer;
  if v_code is null then
    v_code:='DL-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,7));
    insert into public.referral_codes(branch_id,customer_id,code) values(p_branch_id,v_customer,v_code);
  end if;
  return v_code;
end $$;
grant execute on function public.ensure_referral_code(uuid) to authenticated;

create or replace function public.claim_referral_code(p_branch_id uuid,p_code text) returns boolean language plpgsql security definer set search_path='' as $$
declare v_customer uuid; v_referral_code public.referral_codes%rowtype;
begin
  select id into v_customer from public.customers where user_id=(select auth.uid());
  if v_customer is null then raise exception 'Necesitas completar tu cuenta'; end if;
  select * into v_referral_code from public.referral_codes where branch_id=p_branch_id and upper(code)=upper(trim(p_code)) and is_active=true;
  if not found then raise exception 'Código de referido inválido'; end if;
  if v_referral_code.customer_id=v_customer then raise exception 'No puedes usar tu propio código'; end if;
  insert into public.referrals(branch_id,referral_code_id,referred_customer_id) values(p_branch_id,v_referral_code.id,v_customer);
  return true;
exception when unique_violation then raise exception 'Esta cuenta ya usó un código de referido';
end $$;
grant execute on function public.claim_referral_code(uuid,text) to authenticated;

create or replace function public.reward_qualified_referral() returns trigger language plpgsql security definer set search_path='' as $$
declare v_ref public.referrals%rowtype; v_referrer uuid; v_referrer_account uuid; v_referred_account uuid; v_points integer:=50;
begin
  if new.status='delivered' and old.status is distinct from 'delivered' and new.customer_id is not null then
    select * into v_ref from public.referrals where branch_id=new.branch_id and referred_customer_id=new.customer_id and status='registered' for update skip locked;
    if found then
      select customer_id into v_referrer from public.referral_codes where id=v_ref.referral_code_id;
      insert into public.loyalty_accounts(customer_id) values(v_referrer) on conflict(customer_id) do nothing;
      insert into public.loyalty_accounts(customer_id) values(new.customer_id) on conflict(customer_id) do nothing;
      select id into v_referrer_account from public.loyalty_accounts where customer_id=v_referrer;
      select id into v_referred_account from public.loyalty_accounts where customer_id=new.customer_id;
      update public.loyalty_accounts set points_balance=points_balance+v_points,lifetime_points=lifetime_points+v_points,updated_at=now() where id in(v_referrer_account,v_referred_account);
      insert into public.loyalty_movements(loyalty_account_id,order_id,movement_type,points,description) values(v_referrer_account,null,'adjustment',v_points,'Recompensa por recomendación · pedido DL-'||new.folio),(v_referred_account,null,'adjustment',v_points,'Bienvenida por código de referido · pedido DL-'||new.folio);
      update public.referrals set status='rewarded',reward_points=v_points,qualified_at=now() where id=v_ref.id;
    end if;
  end if;
  return new;
end $$;
drop trigger if exists orders_reward_referral on public.orders;
create trigger orders_reward_referral after update of status on public.orders for each row execute function public.reward_qualified_referral();

grant select on public.marketing_content,public.combos,public.product_sales_stats,public.loyalty_rewards to anon,authenticated;
grant select on public.loyalty_redemptions,public.referral_codes,public.referrals to authenticated;
grant insert,update,delete on public.marketing_content,public.combos,public.loyalty_rewards to authenticated;
