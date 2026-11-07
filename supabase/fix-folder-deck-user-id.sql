-- Compatibilidade para instalações anteriores.
-- Use quando as tabelas folders e decks já existirem sem DEFAULT auth.uid().
alter table public.folders
  alter column user_id set default auth.uid();

alter table public.decks
  alter column user_id set default auth.uid();
