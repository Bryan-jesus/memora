-- MEMORA — schema PostgreSQL para Supabase
-- Execute este arquivo inteiro no Supabase Dashboard > SQL Editor.
-- Substitua YOUR_ADMIN_EMAIL@example.com pelo e-mail administrativo escolhido.

create extension if not exists pgcrypto;

create table if not exists public.folders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name varchar(120) not null check (length(trim(name)) > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, user_id)
);

create table if not exists public.decks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  folder_id uuid,
  name varchar(120) not null check (length(trim(name)) > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, user_id),
  foreign key (folder_id, user_id)
    references public.folders(id, user_id)
    on delete set null (folder_id)
);

create table if not exists public.cards (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  deck_id uuid not null,
  card_type varchar(20) not null check (card_type in ('discursive','multiple_choice')),
  question text not null check (length(trim(question)) > 0),
  answer_text text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, user_id),
  foreign key (deck_id, user_id)
    references public.decks(id, user_id)
    on delete cascade,
  check (card_type = 'multiple_choice' or answer_text is not null)
);

create table if not exists public.card_options (
  id uuid primary key default gen_random_uuid(),
  card_id uuid not null references public.cards(id) on delete cascade,
  content text not null check (length(trim(content)) > 0),
  position smallint not null check (position between 1 and 10),
  is_correct boolean not null default false,
  unique (card_id, position)
);
create unique index if not exists one_correct_option_per_card
  on public.card_options(card_id) where is_correct = true;

create table if not exists public.card_review_states (
  user_id uuid not null references auth.users(id) on delete cascade,
  card_id uuid not null,
  level smallint not null default 0 check (level between 0 and 6),
  reviews_count integer not null default 0 check (reviews_count >= 0),
  last_reviewed_at timestamptz,
  next_review_at timestamptz not null,
  updated_at timestamptz not null default now(),
  primary key (user_id, card_id),
  foreign key (card_id, user_id)
    references public.cards(id, user_id)
    on delete cascade
);
create index if not exists idx_review_due
  on public.card_review_states(user_id, next_review_at);

create table if not exists public.card_reviews (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  card_id uuid not null,
  level_before smallint not null check (level_before between 0 and 6),
  level_after smallint not null check (level_after between 1 and 6),
  interval_days integer not null check (interval_days in (1,7,15,30,60,120)),
  scheduled_for timestamptz not null,
  reviewed_at timestamptz not null default now(),
  presented_question text not null,
  submitted_answer text,
  selected_option_text text,
  score smallint not null check (score between 0 and 5),
  feedback text,
  idempotency_key uuid not null,
  unique (user_id, idempotency_key),
  foreign key (card_id, user_id)
    references public.cards(id, user_id)
    on delete cascade
);
create index if not exists idx_card_reviews_history
  on public.card_reviews(user_id, card_id, reviewed_at desc);

create or replace function public.create_initial_review_state()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.card_review_states(user_id, card_id, level, reviews_count, next_review_at)
  values (new.user_id, new.id, 0, 0, new.created_at);
  return new;
end;
$$;

drop trigger if exists trg_create_initial_review_state on public.cards;
create trigger trg_create_initial_review_state
after insert on public.cards
for each row execute function public.create_initial_review_state();

create or replace function public.submit_card_review(
  p_card_id uuid,
  p_presented_question text,
  p_submitted_answer text,
  p_selected_option_id uuid,
  p_score smallint,
  p_feedback text,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_state public.card_review_states%rowtype;
  v_card public.cards%rowtype;
  v_existing public.card_reviews%rowtype;
  v_option public.card_options%rowtype;
  v_score smallint;
  v_new_level smallint;
  v_interval_days integer;
  v_reviewed_at timestamptz;
  v_review public.card_reviews%rowtype;
  v_selected_text text := null;
begin
  if v_user_id is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;

  select * into v_existing
    from public.card_reviews
   where user_id = v_user_id and idempotency_key = p_idempotency_key;
  if found then
    select * into v_state from public.card_review_states
     where user_id = v_user_id and card_id = p_card_id;
    return jsonb_build_object('duplicate', true, 'review', to_jsonb(v_existing), 'state', to_jsonb(v_state));
  end if;

  select * into v_card from public.cards where id = p_card_id and user_id = v_user_id;
  if not found then raise exception 'CARD_NOT_FOUND'; end if;

  select * into v_state from public.card_review_states
   where user_id = v_user_id and card_id = p_card_id
   for update;
  if not found then raise exception 'REVIEW_STATE_NOT_FOUND'; end if;

  select * into v_existing
    from public.card_reviews
   where user_id = v_user_id and idempotency_key = p_idempotency_key;
  if found then
    return jsonb_build_object('duplicate', true, 'review', to_jsonb(v_existing), 'state', to_jsonb(v_state));
  end if;

  v_reviewed_at := clock_timestamp();
  if v_state.next_review_at > v_reviewed_at then raise exception 'CARD_NOT_DUE'; end if;

  if v_card.card_type = 'multiple_choice' then
    select * into v_option from public.card_options
     where id = p_selected_option_id and card_id = p_card_id;
    if not found then raise exception 'INVALID_OPTION'; end if;
    v_score := case when v_option.is_correct then 5 else 0 end;
    v_selected_text := v_option.content;
  else
    if p_score is null or p_score < 0 or p_score > 5 then raise exception 'INVALID_SCORE'; end if;
    v_score := p_score;
  end if;

  v_new_level := least(v_state.level + 1, 6);
  v_interval_days := (array[1,7,15,30,60,120])[v_new_level];

  insert into public.card_reviews(
    user_id, card_id, level_before, level_after, interval_days,
    scheduled_for, reviewed_at, presented_question, submitted_answer,
    selected_option_text, score, feedback, idempotency_key
  ) values (
    v_user_id, p_card_id, v_state.level, v_new_level, v_interval_days,
    v_state.next_review_at, v_reviewed_at, p_presented_question,
    p_submitted_answer, v_selected_text, v_score, p_feedback, p_idempotency_key
  ) returning * into v_review;

  update public.card_review_states
     set level = v_new_level,
         reviews_count = reviews_count + 1,
         last_reviewed_at = v_reviewed_at,
         next_review_at = v_reviewed_at + (v_interval_days * interval '24 hours'),
         updated_at = v_reviewed_at
   where user_id = v_user_id and card_id = p_card_id
   returning * into v_state;

  return jsonb_build_object(
    'duplicate', false,
    'review', to_jsonb(v_review),
    'state', to_jsonb(v_state),
    'interval_days', v_interval_days
  );
end;
$$;

create or replace function public.is_memora_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select lower(coalesce(auth.jwt() ->> 'email', '')) = 'YOUR_ADMIN_EMAIL@example.com';
$$;

revoke all on function public.is_memora_admin() from public, anon;
grant execute on function public.is_memora_admin() to authenticated;

alter table public.folders enable row level security;
alter table public.decks enable row level security;
alter table public.cards enable row level security;
alter table public.card_options enable row level security;
alter table public.card_review_states enable row level security;
alter table public.card_reviews enable row level security;

drop policy if exists folders_owner_all on public.folders;
create policy folders_owner_all on public.folders
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists decks_owner_all on public.decks;
create policy decks_owner_all on public.decks
  for all to authenticated using (user_id = auth.uid())
  with check (
    user_id = auth.uid() and
    (folder_id is null or exists (
      select 1 from public.folders f where f.id = folder_id and f.user_id = auth.uid()
    ))
  );

drop policy if exists cards_owner_all on public.cards;
create policy cards_owner_all on public.cards
  for all to authenticated using (user_id = auth.uid())
  with check (
    user_id = auth.uid() and exists (
      select 1 from public.decks d where d.id = deck_id and d.user_id = auth.uid()
    )
  );

drop policy if exists options_owner_all on public.card_options;
create policy options_owner_all on public.card_options
  for all to authenticated using (exists (
    select 1 from public.cards c where c.id = card_id and c.user_id = auth.uid()
  )) with check (exists (
    select 1 from public.cards c where c.id = card_id and c.user_id = auth.uid()
  ));

drop policy if exists states_owner_all on public.card_review_states;
create policy states_owner_all on public.card_review_states
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists reviews_owner_all on public.card_reviews;
create policy reviews_owner_all on public.card_reviews
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

grant usage on schema public to authenticated;
grant select, insert, update, delete on public.folders, public.decks, public.cards, public.card_options to authenticated;
grant select on public.card_review_states, public.card_reviews to authenticated;
revoke all on function public.submit_card_review(uuid,text,text,uuid,smallint,text,uuid) from public, anon;
grant execute on function public.submit_card_review(uuid,text,text,uuid,smallint,text,uuid) to authenticated;
