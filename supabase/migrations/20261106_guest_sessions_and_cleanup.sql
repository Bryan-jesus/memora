-- Memora: sessões anônimas temporárias com exclusão imediata ao sair
-- e limpeza automática de fallback após 1 hora de inatividade.
-- Execute uma única vez no Supabase SQL Editor.

begin;

create table if not exists public.memora_guest_sessions (
  user_id uuid primary key references auth.users(id) on delete cascade,
  expires_at timestamptz not null,
  last_seen_at timestamptz not null default now()
);

alter table public.memora_guest_sessions enable row level security;
revoke all on public.memora_guest_sessions from anon, authenticated;

create or replace function public.track_memora_guest_user()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if new.is_anonymous is true then
    insert into public.memora_guest_sessions(user_id, expires_at, last_seen_at)
    values (new.id, now() + interval '1 hour', now())
    on conflict (user_id) do update
      set expires_at = excluded.expires_at,
          last_seen_at = excluded.last_seen_at;
  end if;
  return new;
end;
$$;

revoke all on function public.track_memora_guest_user() from public, anon, authenticated;
drop trigger if exists trg_track_memora_guest_user on auth.users;
create trigger trg_track_memora_guest_user
  after insert on auth.users
  for each row execute function public.track_memora_guest_user();

create or replace function public.touch_memora_guest_session()
returns timestamptz
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_expiry timestamptz;
begin
  if auth.uid() is null or not exists (
    select 1 from auth.users u where u.id = auth.uid() and u.is_anonymous is true
  ) then
    raise exception 'ANONYMOUS_SESSION_REQUIRED';
  end if;

  insert into public.memora_guest_sessions(user_id, expires_at, last_seen_at)
  values (auth.uid(), now() + interval '1 hour', now())
  on conflict (user_id) do update
    set expires_at = excluded.expires_at,
        last_seen_at = excluded.last_seen_at
  returning expires_at into v_expiry;
  return v_expiry;
end;
$$;
revoke all on function public.touch_memora_guest_session() from public, anon;
grant execute on function public.touch_memora_guest_session() to authenticated;

create or replace function public.cleanup_expired_memora_guests()
returns integer
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_deleted integer;
begin
  delete from auth.users u
   using public.memora_guest_sessions g
   where g.user_id = u.id
     and g.expires_at <= now()
     and u.is_anonymous is true;
  get diagnostics v_deleted = row_count;
  return v_deleted;
end;
$$;
revoke all on function public.cleanup_expired_memora_guests() from public, anon, authenticated;

create extension if not exists pg_cron with schema pg_catalog;

do $$
declare
  v_job record;
begin
  for v_job in select jobid from cron.job where jobname = 'memora-cleanup-expired-guests' loop
    perform cron.unschedule(v_job.jobid);
  end loop;
  perform cron.schedule(
    'memora-cleanup-expired-guests',
    '*/15 * * * *',
    'select public.cleanup_expired_memora_guests();'
  );
end;
$$;

notify pgrst, 'reload schema';
commit;
