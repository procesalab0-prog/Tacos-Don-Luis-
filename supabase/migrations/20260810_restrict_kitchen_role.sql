alter policy "staff manage ingredients" on public.ingredients
using (app_private.is_branch_staff(branch_id, array['owner'::text, 'admin'::text, 'cashier'::text]))
with check (app_private.is_branch_staff(branch_id, array['owner'::text, 'admin'::text, 'cashier'::text]));

alter policy "staff manage inventory movements" on public.inventory_movements
using (app_private.is_branch_staff(branch_id, array['owner'::text, 'admin'::text, 'cashier'::text]))
with check (app_private.is_branch_staff(branch_id, array['owner'::text, 'admin'::text, 'cashier'::text]));

alter policy "staff manage inventory stocks" on public.inventory_stocks
using (app_private.is_branch_staff(branch_id, array['owner'::text, 'admin'::text, 'cashier'::text]))
with check (app_private.is_branch_staff(branch_id, array['owner'::text, 'admin'::text, 'cashier'::text]));

alter policy "operations read purchase items" on public.purchase_order_items
using (exists (
  select 1 from public.purchase_orders po
  where po.id = purchase_order_items.purchase_order_id
    and app_private.is_branch_staff(po.branch_id, array['owner'::text, 'admin'::text, 'cashier'::text])
));

alter policy "operations read purchases" on public.purchase_orders
using (app_private.is_branch_staff(branch_id, array['owner'::text, 'admin'::text, 'cashier'::text]));

alter policy "staff manage recipes" on public.recipes
using (exists (
  select 1 from public.products p
  where p.id = recipes.product_id
    and app_private.is_branch_staff(p.branch_id, array['owner'::text, 'admin'::text])
))
with check (exists (
  select 1 from public.products p
  where p.id = recipes.product_id
    and app_private.is_branch_staff(p.branch_id, array['owner'::text, 'admin'::text])
));

alter policy "staff read suppliers" on public.suppliers
using (app_private.is_branch_staff(branch_id, array['owner'::text, 'admin'::text, 'cashier'::text]));
