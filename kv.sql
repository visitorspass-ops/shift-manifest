-- =====================================================================
-- Shared store for the Shift Manifest.
--
-- The app already funnels EVERY read and write — day events, order
-- ladders, summaries, name maps, attendance, break permits, exclusions —
-- through one key/value shim with four methods (get/set/del/keys). So the
-- whole application becomes multi-user by pointing that shim at this table.
-- No view, drawer or formula changes.
--
-- Keys keep their existing prefixes: ev:YYYY-MM-DD, ladder:…, sum:…,
-- names:main, att:main, permits:main, excluded:main, and so on.
-- =====================================================================

create table if not exists kv (
  key         text primary key,
  value       jsonb not null,
  updated_at  timestamptz not null default now(),
  updated_by  uuid references auth.users (id)
);

create index if not exists kv_key_prefix_idx on kv (key text_pattern_ops);

alter table kv enable row level security;

-- Anyone signed in with a role may READ the data.
drop policy if exists "signed-in users read kv" on kv;
create policy "signed-in users read kv"
  on kv for select
  to authenticated
  using (exists (select 1 from user_roles ur where ur.user_id = auth.uid()));

-- Only admins may WRITE. Uploading a transaction log rewrites shared
-- history for everyone, so it is deliberately not a supervisor action.
drop policy if exists "admins write kv" on kv;
create policy "admins write kv"
  on kv for all
  to authenticated
  using      (exists (select 1 from user_roles ur where ur.user_id = auth.uid() and ur.role = 'admin'))
  with check (exists (select 1 from user_roles ur where ur.user_id = auth.uid() and ur.role = 'admin'));

-- Light index so the app can list stored days without pulling payloads.
create or replace view kv_keys as select key, updated_at from kv;
