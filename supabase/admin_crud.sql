-- Run once in the Supabase SQL Editor after creating public.products.
-- Product reads stay public; only users with app_metadata.role = 'admin'
-- can create, edit, or delete catalog rows.

create or replace function public.is_catalog_admin()
returns boolean
language sql
stable
as $$
  select coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '') = 'admin';
$$;

revoke all on function public.is_catalog_admin() from public;
grant execute on function public.is_catalog_admin() to authenticated;
grant insert, update, delete on public.products to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'products'
      and policyname = 'Admins can add products'
  ) then
    execute 'create policy "Admins can add products"
      on public.products for insert to authenticated
      with check ((select public.is_catalog_admin()))';
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'products'
      and policyname = 'Admins can edit products'
  ) then
    execute 'create policy "Admins can edit products"
      on public.products for update to authenticated
      using ((select public.is_catalog_admin()))
      with check ((select public.is_catalog_admin()))';
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'products'
      and policyname = 'Admins can delete products'
  ) then
    execute 'create policy "Admins can delete products"
      on public.products for delete to authenticated
      using ((select public.is_catalog_admin()))';
  end if;
end
$$;

-- After creating an Auth user in Supabase Dashboard > Authentication > Users,
-- make that user an admin by replacing the email below and running this block.
-- Then sign out and back in from the app so the refreshed JWT carries the claim.
--
-- update auth.users
-- set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb)
--     || '{"role":"admin"}'::jsonb
-- where lower(email) = lower('your-email@example.com');
