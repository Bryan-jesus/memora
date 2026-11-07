-- Memora migration: primeira revisão imediata, segunda em 24 horas,
-- progressão fixa posterior e controle interno exclusivo.
-- Execute uma única vez no Supabase SQL Editor.

begin;

-- Libera nomes duplicados em decks; o frontend solicita confirmação.
do $$
declare
  item record;
begin
  for item in
    select conname
      from pg_constraint
     where conrelid = 'public.decks'::regclass
       and contype = 'u'
       and pg_get_constraintdef(oid) ilike 'UNIQUE (user_id, folder_id, name)%'
  loop
    execute format('alter table public.decks drop constraint %I', item.conname);
  end loop;
end;
$$;

alter table public.card_reviews
  drop constraint if exists card_reviews_interval_days_check;
alter table public.card_reviews
  add constraint card_reviews_interval_days_check
  check (interval_days in (1, 7, 15, 30, 60, 120));

-- Cartões ainda nunca revisados ficam disponíveis imediatamente.
update public.card_review_states s
   set next_review_at = c.created_at,
       updated_at = now()
  from public.cards c
 where c.id = s.card_id
   and c.user_id = s.user_id
   and s.level = 0
   and s.reviews_count = 0
   and s.last_reviewed_at is null;

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

-- Após a 1ª revisão: +24h. Após a 2ª: +7 dias; depois +15, +30, +60 e +120.
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

  select * into v_card from public.cards
   where id = p_card_id and user_id = v_user_id;
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
  v_interval_days := (array[1, 7, 15, 30, 60, 120])[v_new_level];

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

-- Substitua YOUR_ADMIN_EMAIL@example.com pelo e-mail administrativo desejado.
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

revoke all on function public.submit_card_review(uuid,text,text,uuid,smallint,text,uuid) from public, anon;
grant execute on function public.submit_card_review(uuid,text,text,uuid,smallint,text,uuid) to authenticated;

notify pgrst, 'reload schema';
commit;
