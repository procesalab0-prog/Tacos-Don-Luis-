CREATE OR REPLACE FUNCTION public.driver_advance_assignment(p_assignment_id uuid, p_action text, p_incident_note text DEFAULT NULL::text)
 RETURNS driver_assignments
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_assignment public.driver_assignments;
  v_order public.orders;
  v_is_leadership boolean;
begin
  if (select auth.uid()) is null then raise exception 'authentication required'; end if;
  select * into v_assignment from public.driver_assignments where id=p_assignment_id for update;
  if not found then raise exception 'assignment not found'; end if;
  select * into v_order from public.orders where id=v_assignment.order_id for update;
  select exists(select 1 from public.branch_memberships bm where bm.user_id=(select auth.uid()) and bm.branch_id=v_order.branch_id and bm.role in ('owner','admin') and bm.is_active) into v_is_leadership;
  if v_assignment.driver_user_id <> (select auth.uid()) and not v_is_leadership then raise exception 'assignment access denied'; end if;
  if not v_is_leadership and not exists(select 1 from public.branch_memberships bm where bm.user_id=(select auth.uid()) and bm.branch_id=v_order.branch_id and bm.role='driver' and bm.is_active) then raise exception 'active driver membership required'; end if;
  if p_action='picked_up' and v_assignment.status in ('assigned','accepted') then
    update public.driver_assignments set status='picked_up',picked_up_at=now() where id=p_assignment_id returning * into v_assignment;
    update public.orders set status='on_the_way',updated_at=now() where id=v_assignment.order_id;
  elsif p_action='delivered' and v_assignment.status in ('picked_up','on_the_way') then
    update public.driver_assignments set status='delivered',delivered_at=now() where id=p_assignment_id returning * into v_assignment;
    update public.orders set status='delivered',completed_at=now(),payment_status=case when payment_method='cash' then 'paid' else payment_status end,updated_at=now() where id=v_assignment.order_id;
  elsif p_action='incident' and v_assignment.status in ('assigned','picked_up','on_the_way') and length(trim(coalesce(p_incident_note,'')))>0 then
    update public.driver_assignments set status='incident',incident_note=left(trim(p_incident_note),500) where id=p_assignment_id returning * into v_assignment;
  update public.orders set status='failed_delivery',updated_at=now() where id=v_assignment.order_id;
  else raise exception 'invalid transition'; end if;
  return v_assignment;
end;
$function$

