revoke all on function public.claim_referral_code(uuid,text) from public,anon;
revoke all on function public.ensure_referral_code(uuid) from public,anon;
revoke all on function public.redeem_loyalty_reward(uuid) from public,anon;
grant execute on function public.claim_referral_code(uuid,text) to authenticated;
grant execute on function public.ensure_referral_code(uuid) to authenticated;
grant execute on function public.redeem_loyalty_reward(uuid) to authenticated;

revoke all on function public.record_product_sales() from public,anon,authenticated;
revoke all on function public.reward_qualified_referral() from public,anon,authenticated;

create index if not exists loyalty_redemptions_account_idx on public.loyalty_redemptions(loyalty_account_id);
create index if not exists loyalty_redemptions_reward_idx on public.loyalty_redemptions(reward_id);
create index if not exists loyalty_rewards_branch_idx on public.loyalty_rewards(branch_id,is_active,sort_order);
create index if not exists loyalty_rewards_category_idx on public.loyalty_rewards(qualifying_category_id) where qualifying_category_id is not null;
create index if not exists loyalty_rewards_product_idx on public.loyalty_rewards(reward_product_id) where reward_product_id is not null;
create index if not exists marketing_content_product_idx on public.marketing_content(product_id) where product_id is not null;
create index if not exists product_sales_stats_product_idx on public.product_sales_stats(product_id);
create index if not exists referral_codes_customer_idx on public.referral_codes(customer_id);
create index if not exists referrals_code_idx on public.referrals(referral_code_id);
create index if not exists referrals_customer_idx on public.referrals(referred_customer_id);
