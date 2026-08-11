alter table public.loyalty_rewards add column if not exists qualifying_category_id uuid references public.categories(id) on delete set null;

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
    select count(*) into v_used from public.loyalty_redemptions where loyalty_account_id=v_account.id and reward_id=v_reward.id and status<>'cancelled';
    if v_purchases < v_reward.required_purchases*(v_used+1) then raise exception 'Aún no completas las compras necesarias'; end if;
  end if;
  if v_reward.reward_type='buy_x_get_y' then
    select coalesce(sum(oi.quantity),0) into v_units
    from public.orders o join public.order_items oi on oi.order_id=o.id left join public.products p on p.id=oi.product_id
    where o.customer_id=v_customer and o.branch_id=v_reward.branch_id and o.status='delivered'
      and (v_reward.qualifying_category_id is null or p.category_id=v_reward.qualifying_category_id);
    select count(*) into v_used from public.loyalty_redemptions where loyalty_account_id=v_account.id and reward_id=v_reward.id and status<>'cancelled';
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

insert into public.loyalty_rewards(branch_id,name,description,reward_type,points_cost,required_purchases,required_product_quantity,qualifying_category_id,reward_quantity,is_active,sort_order)
select b.id,'Taco gratis por cada 10','Compra 10 tacos y canjea el número 11 sin costo.','buy_x_get_y',0,0,10,c.id,1,true,10
from public.branches b join public.categories c on c.branch_id=b.id and lower(c.name)='tacos'
where b.slug='punto-canada' and not exists(select 1 from public.loyalty_rewards r where r.branch_id=b.id and r.reward_type='buy_x_get_y');

insert into public.loyalty_rewards(branch_id,name,description,reward_type,points_cost,required_purchases,required_product_quantity,reward_quantity,is_active,sort_order)
select b.id,'Premio por 5 compras','Completa cinco pedidos entregados y recibe un premio en caja.','purchase_count',0,5,0,1,true,20
from public.branches b where b.slug='punto-canada' and not exists(select 1 from public.loyalty_rewards r where r.branch_id=b.id and r.reward_type='purchase_count');

insert into public.loyalty_rewards(branch_id,name,description,reward_type,points_cost,required_purchases,required_product_quantity,reward_quantity,is_active,sort_order)
select b.id,'Premio de 200 puntos','Canjea tus puntos por una recompensa autorizada en caja.','points',200,0,0,1,true,30
from public.branches b where b.slug='punto-canada' and not exists(select 1 from public.loyalty_rewards r where r.branch_id=b.id and r.reward_type='points');
