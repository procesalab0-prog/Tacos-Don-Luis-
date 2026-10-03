create or replace function public.create_guest_order_atomic(p_order jsonb,p_lines jsonb,p_points integer default 0)
returns jsonb language plpgsql security definer set search_path='' as $$
declare o public.orders; v public.orders; line jsonb; option jsonb; item_id uuid;
begin
 v:=jsonb_populate_record(null::public.orders,p_order);
 if v.client_request_id is null or jsonb_array_length(p_lines) not between 1 and 50 then raise exception 'Invalid request'; end if;
 perform pg_advisory_xact_lock(hashtextextended(v.client_request_id::text,73));
 select * into o from public.orders where client_request_id=v.client_request_id;
 if found then return jsonb_build_object('order',jsonb_build_object('id',o.id,'folio',o.folio,'public_code',o.public_code,'status',o.status,'total',o.total,'promised_at',o.promised_at,'loyalty_points_redeemed',o.loyalty_points_redeemed,'loyalty_discount',o.loyalty_discount),'duplicate',true); end if;
 perform pg_advisory_xact_lock(hashtextextended(v.branch_id::text||v.guest_phone,74));
 if (select count(*) from public.orders where branch_id=v.branch_id and guest_phone=v.guest_phone and created_at>now()-interval '10 minutes')>=6 then raise exception 'Demasiados pedidos; espera unos minutos'; end if;
 insert into public.orders(client_request_id,tracking_token_hash,branch_id,customer_user_id,customer_id,is_demo,guest_name,guest_phone,channel,fulfillment_type,status,payment_method,payment_status,promised_at,scheduled_for,delivery_address,delivery_zone_id,customer_notes,subtotal,discount_total,delivery_fee,total)
 values(v.client_request_id,v.tracking_token_hash,v.branch_id,v.customer_user_id,v.customer_id,v.is_demo,v.guest_name,v.guest_phone,'web',v.fulfillment_type,'pending_acceptance',v.payment_method,v.payment_status,v.promised_at,v.scheduled_for,v.delivery_address,v.delivery_zone_id,v.customer_notes,v.subtotal,v.discount_total,v.delivery_fee,v.total) returning * into o;
 for line in select value from jsonb_array_elements(p_lines) loop
   if (line->>'quantity')::numeric<>trunc((line->>'quantity')::numeric) or (line->>'quantity')::integer not between 1 and 30 then raise exception 'Cantidad inválida'; end if;
   insert into public.order_items(order_id,product_id,product_name,unit_price,quantity,notes,line_total)
   values(o.id,(line->>'product_id')::uuid,line->>'product_name',(line->>'unit_price')::numeric,(line->>'quantity')::integer,line->>'notes',(line->>'line_total')::numeric) returning id into item_id;
   for option in select value from jsonb_array_elements(coalesce(line->'modifiers','[]')) loop
     insert into public.order_item_modifiers(order_item_id,modifier_option_id,option_name,price_delta)
     values(item_id,(option->>'id')::uuid,option->>'name',(option->>'price_delta')::numeric);
   end loop;
 end loop;
 insert into public.order_status_history(order_id,from_status,to_status,note) values(o.id,null,'pending_acceptance','Pedido recibido desde la web');
 if p_points>0 then
   if o.customer_id is null then raise exception 'Inicia sesión para pagar con puntos'; end if;
   perform public.apply_loyalty_points_to_order(o.id,o.customer_id,p_points);
   select * into o from public.orders where id=o.id;
 end if;
 return jsonb_build_object('order',jsonb_build_object('id',o.id,'folio',o.folio,'public_code',o.public_code,'status',o.status,'total',o.total,'promised_at',o.promised_at,'loyalty_points_redeemed',o.loyalty_points_redeemed,'loyalty_discount',o.loyalty_discount),'duplicate',false);
end $$;
revoke all on function public.create_guest_order_atomic(jsonb,jsonb,integer) from public,anon,authenticated;
grant execute on function public.create_guest_order_atomic(jsonb,jsonb,integer) to service_role;
