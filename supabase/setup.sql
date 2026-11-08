-- =====================================================================
-- Artemis TAK: full database setup (run ONCE in Supabase SQL Editor)
-- Base tables are rebuilt from what index.html expects, because the
-- RO-TAK repo only ships the add-on files. The four repo .sql files are
-- included below in the right order (moderation, host, editors, limit).
-- =====================================================================

-- ---------- Base tables ----------
create table if not exists public.rooms (
  code        text primary key,
  map_path    text,
  grid        text,
  credit      text,
  last_active timestamptz not null default now(),
  created_at  timestamptz not null default now()
);

create table if not exists public.marks (
  id         text primary key,
  room       text not null references public.rooms(code) on delete cascade,
  data       jsonb not null,
  created_at timestamptz not null default now()
);
create index if not exists marks_room_idx on public.marks (room, created_at);

-- ---------- Access (no accounts: everyone uses the public key) ----------
alter table public.rooms enable row level security;
alter table public.marks enable row level security;

drop policy if exists rooms_all on public.rooms;
create policy rooms_all on public.rooms for all to anon, authenticated using (true) with check (true);
drop policy if exists marks_all on public.marks;
create policy marks_all on public.marks for all to anon, authenticated using (true) with check (true);

grant select, insert, update, delete on public.rooms, public.marks to anon, authenticated;

-- ---------- Live sync ----------
do $$
begin
  begin alter publication supabase_realtime add table public.rooms; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.marks; exception when duplicate_object then null; end;
end $$;

-- ==================== moderation.sql ====================
create or replace function public.is_bad(t text) returns boolean
language plpgsql immutable as $$
declare n text; w text; sq text;
begin
  if t is null or t = '' then return false; end if;
  n := translate(lower(t), '0134578@$!|', 'oieastbasii');
  w := regexp_replace(n, '[^a-z]+', ' ', 'g');
  sq := regexp_replace(n, '[^a-z]', '', 'g');
  return w ~ '\y(?:nigg(?:er|a|ah|uh|az|as)s?|fag(?:s|got|gots|git|it|ot)?|dykes?|trann(?:y|ies)|shemales?|chinks?|gooks?|spic(?:s|k|ks)?|kikes?|coons?|wetbacks?|beaners?|pakis?|towelheads?|japs?|darkies?|retard(?:s|ed)?)\y'
      or sq ~ 'n+i+g{2,}(?:e+r+|a+h+|a+(?!r))|f+a+g{2,}o+t+';
end $$;

create or replace function public.reject_bad_marks() returns trigger
language plpgsql as $$
declare txt text;
begin
  select string_agg(x #>> '{}', ' ') into txt
  from jsonb_path_query(new.data::jsonb, '$.**') x
  where jsonb_typeof(x) = 'string';
  if public.is_bad(txt) then raise exception 'Text not allowed'; end if;
  return new;
end $$;
drop trigger if exists marks_bad on public.marks;
create trigger marks_bad before insert or update on public.marks
for each row execute function public.reject_bad_marks();

create or replace function public.reject_bad_room() returns trigger
language plpgsql as $$
begin
  if public.is_bad(new.code) then raise exception 'Room code not allowed'; end if;
  return new;
end $$;
drop trigger if exists rooms_bad on public.rooms;
create trigger rooms_bad before insert or update on public.rooms
for each row execute function public.reject_bad_room();

do $$
declare p record;
begin
  for p in
    select policyname from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and (coalesce(with_check, '') ilike '%maps%' or coalesce(qual, '') ilike '%maps%')
  loop
    execute format('drop policy %I on storage.objects', p.policyname);
  end loop;
end $$;

-- ==================== host.sql ====================

alter table public.rooms add column if not exists host_hash text;
alter table public.rooms add column if not exists locked boolean not null default false;

create or replace function public.is_host(r text) returns boolean
language plpgsql stable as $$
declare k text; h text;
begin
  select host_hash into h from public.rooms where code = r;
  if h is null then return false; end if;
  k := coalesce((nullif(current_setting('request.headers', true), '')::json) ->> 'x-host-key', '');
  return k <> '' and encode(sha256(convert_to(k, 'utf8')), 'hex') = h;
end $$;

create or replace function public.guard_marks() returns trigger
language plpgsql as $$
declare rc text; lk boolean;
begin
  if current_user not in ('anon', 'authenticated') then
    if tg_op = 'DELETE' then return old; end if; return new;
  end if;
  if tg_op = 'DELETE' then rc := old.room; else rc := new.room; end if;
  select locked into lk from public.rooms where code = rc;
  if coalesce(lk, false) and not public.is_host(rc) then raise exception 'Room is locked'; end if;
  if tg_op = 'DELETE' then return old; end if; return new;
end $$;
drop trigger if exists marks_guard on public.marks;
create trigger marks_guard before insert or update or delete on public.marks
  for each row execute function public.guard_marks();

create or replace function public.guard_marks_bulk() returns trigger
language plpgsql as $$
declare n int; rc text;
begin
  if current_user not in ('anon', 'authenticated') then return null; end if;
  select count(*) into n from old_rows;
  if n > 50 then
    for rc in select distinct room from old_rows loop
      if exists (select 1 from public.rooms where code = rc and host_hash is not null) and not public.is_host(rc) then
        raise exception 'Only the host can clear the room';
      end if;
    end loop;
  end if;
  return null;
end $$;
drop trigger if exists marks_guard_bulk on public.marks;
create trigger marks_guard_bulk after delete on public.marks
  referencing old table as old_rows for each statement execute function public.guard_marks_bulk();

create or replace function public.guard_rooms() returns trigger
language plpgsql as $$
begin
  if current_user not in ('anon', 'authenticated') then
    if tg_op = 'DELETE' then return old; end if; return new;
  end if;
  if tg_op = 'DELETE' then
    if old.host_hash is not null and not public.is_host(old.code) then raise exception 'Only the host can delete the room'; end if;
    return old;
  end if;
  if new.host_hash is distinct from old.host_hash then raise exception 'Not allowed'; end if;
  if new.locked is distinct from old.locked and not public.is_host(old.code) then raise exception 'Only the host can lock the room'; end if;
  if old.host_hash is not null and not public.is_host(old.code) then
    if new.map_path is distinct from old.map_path then raise exception 'Only the host can change the map'; end if;
    if old.locked and (new.grid is distinct from old.grid or new.credit is distinct from old.credit) then raise exception 'Room is locked'; end if;
  end if;
  return new;
end $$;
drop trigger if exists rooms_guard on public.rooms;
create trigger rooms_guard before update or delete on public.rooms
  for each row execute function public.guard_rooms();

-- ==================== editors.sql ====================
alter table public.rooms add column if not exists editor_hash text;

create or replace function public.is_editor(r text) returns boolean
language plpgsql stable as $$
declare k text; h text;
begin
  select editor_hash into h from public.rooms where code = r;
  if h is null then return false; end if;
  k := coalesce((nullif(current_setting('request.headers', true), '')::json) ->> 'x-editor-key', '');
  return k <> '' and encode(sha256(convert_to(k, 'utf8')), 'hex') = h;
end $$;

create or replace function public.guard_marks() returns trigger
language plpgsql as $$
declare rc text; lk boolean;
begin
  if current_user not in ('anon', 'authenticated') then
    if tg_op = 'DELETE' then return old; end if; return new;
  end if;
  if tg_op = 'DELETE' then rc := old.room; else rc := new.room; end if;
  select locked into lk from public.rooms where code = rc;
  if coalesce(lk, false) and not public.is_host(rc) and not public.is_editor(rc) then raise exception 'Room is locked'; end if;
  if tg_op = 'DELETE' then return old; end if; return new;
end $$;

create or replace function public.guard_rooms() returns trigger
language plpgsql as $$
begin
  if current_user not in ('anon', 'authenticated') then
    if tg_op = 'DELETE' then return old; end if; return new;
  end if;
  if tg_op = 'DELETE' then
    if old.host_hash is not null and not public.is_host(old.code) then raise exception 'Only the host can delete the room'; end if;
    return old;
  end if;
  if new.host_hash is distinct from old.host_hash then raise exception 'Not allowed'; end if;
  if new.locked is distinct from old.locked and not public.is_host(old.code) then raise exception 'Only the host can lock the room'; end if;
  if new.editor_hash is distinct from old.editor_hash and not public.is_host(old.code) then raise exception 'Only the host can change editors'; end if;
  if old.host_hash is not null and not public.is_host(old.code) then
    if new.map_path is distinct from old.map_path then raise exception 'Only the host can change the map'; end if;
    if old.locked and not public.is_editor(old.code) and (new.grid is distinct from old.grid or new.credit is distinct from old.credit) then raise exception 'Room is locked'; end if;
  end if;
  return new;
end $$;

-- ==================== limit.sql ====================
drop trigger if exists rooms_limit on public.rooms;
drop table if exists public.room_creations;

create table if not exists public.room_limit_salt (
  salt text not null default gen_random_uuid()::text
);
insert into public.room_limit_salt select where not exists (select 1 from public.room_limit_salt);
alter table public.room_limit_salt enable row level security;

create table public.room_creations (
  hash text not null,
  created timestamptz not null default now()
);
create index room_creations_hash_idx on public.room_creations (hash, created);
alter table public.room_creations enable row level security;

create or replace function public.limit_room_creation() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  hdr json;
  caller text;
  h text;
  recent int;
begin
  if exists (select 1 from public.rooms where code = new.code) then
    return new;
  end if;
  begin
    hdr := current_setting('request.headers', true)::json;
  exception when others then
    hdr := null;
  end;
  caller := trim(split_part(coalesce(hdr ->> 'x-forwarded-for', hdr ->> 'cf-connecting-ip', ''), ',', 1));
  if caller = '' then
    return new;
  end if;
  h := encode(sha256(convert_to(caller || (select salt from public.room_limit_salt limit 1), 'utf8')), 'hex');
  delete from public.room_creations where created < now() - interval '1 day';
  select count(*) into recent from public.room_creations where hash = h;
  if recent >= 10 then
    raise exception 'You have created too many rooms today. Rejoin one of your earlier rooms, or try again tomorrow.';
  end if;
  insert into public.room_creations (hash) values (h);
  return new;
end $$;

create trigger rooms_limit before insert on public.rooms
  for each row execute function public.limit_room_creation();