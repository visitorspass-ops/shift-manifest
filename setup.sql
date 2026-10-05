-- =====================================================================
-- Shift Manifest — complete Supabase setup. Run this ONCE, whole, in the
-- SQL Editor of a fresh project. Safe to re-run.
--
-- Creates two tables and nothing else:
--   user_roles  who may see the site, and at what level
--   kv          the shared store the app reads and writes through
--
-- No storage bucket is needed. The browser parses uploaded files itself
-- and writes the result straight to kv — there is no server-side
-- ingestion step in this build.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Roles
-- ---------------------------------------------------------------------
create table if not exists user_roles (
  user_id    uuid not null references auth.users (id) on delete cascade,
  role       text not null check (role in ('admin','supervisor_manager','team_lead')),
  created_at timestamptz not null default now(),
  constraint user_roles_user_id_role_key unique (user_id, role)
);

create index if not exists user_roles_user_id_idx on user_roles (user_id);

alter table user_roles enable row level security;

-- Everyone may read their OWN roles. The app needs this on sign-in to know
-- whether to show the uploader.
drop policy if exists "read own roles" on user_roles;
create policy "read own roles"
  on user_roles for select
  to authenticated
  using (user_id = auth.uid());

-- Admins may read and manage everyone's. Expressed against a SECURITY
-- DEFINER function rather than a sub-select on user_roles itself: a policy
-- on a table that queries the same table recurses and fails at runtime.
create or replace function is_admin(uid uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (select 1 from user_roles where user_id = uid and role = 'admin');
$$;

drop policy if exists "admins manage roles" on user_roles;
create policy "admins manage roles"
  on user_roles for all
  to authenticated
  using      (is_admin(auth.uid()))
  with check (is_admin(auth.uid()));

-- ---------------------------------------------------------------------
-- 2. The shared store
-- ---------------------------------------------------------------------
-- Every read and write in the app — day events, order ladders, summaries,
-- name maps, attendance, break permits, exclusions, coaching log,
-- exceptions, skills certification, team assignments — goes through one
-- key/value shim. This is that store. Keys keep their prefixes:
--   ev:YYYY-MM-DD   ladder:…   sum:…   names:main   permits:main   …
create table if not exists kv (
  key        text primary key,
  value      jsonb not null,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users (id)
);

create index if not exists kv_key_prefix_idx on kv (key text_pattern_ops);

alter table kv enable row level security;

-- Anyone signed in WITH A ROLE may read. A signed-in account with no role
-- granted sees nothing, which is what the sign-in screen tells them.
drop policy if exists "roled users read kv" on kv;
create policy "roled users read kv"
  on kv for select
  to authenticated
  using (exists (select 1 from user_roles ur where ur.user_id = auth.uid()));

-- Only admins may write. Uploading a transaction log rewrites shared
-- history for everyone, so it is deliberately not a supervisor action.
drop policy if exists "admins write kv" on kv;
create policy "admins write kv"
  on kv for all
  to authenticated
  using      (is_admin(auth.uid()))
  with check (is_admin(auth.uid()));

-- ---------------------------------------------------------------------
-- 3. Grant yourself admin
-- ---------------------------------------------------------------------
-- Run this AFTER creating your user under Authentication → Users.
-- Nobody has admin on a fresh project, and the policies above are
-- fail-closed, so without this the site lets you in and shows nothing.
--
--   insert into user_roles (user_id, role)
--   select id, 'admin' from auth.users where email = 'francis.eledia@golocad.com'
--   on conflict (user_id, role) do nothing;
--
-- Check who has what:
--   select u.email, r.role
--   from auth.users u left join user_roles r on r.user_id = u.id
--   order by u.email;
