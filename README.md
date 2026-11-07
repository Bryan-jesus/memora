# Memora

Plataforma de estudos com flashcards, repetição espaçada e apoio de inteligência artificial.

> Projeto pessoal desenvolvido com auxílio de ferramentas de IA (Vibe Coding). O objetivo é aprender, experimentar decisões de produto e evoluir uma aplicação real de forma incremental.

## Funcionalidades

- Login, cadastro e sessões anônimas com Supabase Auth.
- Organização em pastas, decks e cartões.
- Cartões discursivos e de múltipla escolha.
- Primeira revisão disponível imediatamente após a criação; após a primeira revisão, intervalos de 24 horas, 7, 15, 30, 60 e 120 dias.
- Estado atual e histórico de revisões separados no PostgreSQL.
- Reformulação de enunciados e avaliação discursiva com Gemini por Supabase Edge Function.
- Área administrativa restrita, com autorização verificada também no PostgreSQL.
- Modo visitante temporário com expiração e rotina de limpeza.
- Interface responsiva para Cloudflare Pages.

## Tecnologias

- HTML, CSS e JavaScript (ES modules)
- Supabase: PostgreSQL, Auth, Row Level Security e Edge Functions
- Google Gemini API
- Cloudflare Pages
- Supabase CLI

## Estrutura

- `index.html`, `app.js`, `styles.css`: aplicação web.
- `supabase/schema.sql`: esquema inicial do banco.
- `supabase/migrations/`: alterações incrementais do banco.
- `supabase/functions/`: funções Edge de IA e limpeza de sessões visitantes.
- `tests/`: testes automatizados do agendamento.
- `ATIVAR-IA.md`, `ATIVAR-VISITANTE.md`, `ATUALIZAR-PERFORMANCE.md`: guias operacionais.
- `source/memora-source-v7.zip`: pacote completo do código-fonte desta publicação.

## Configuração antes de executar

Este repositório é um template público. Antes de publicar sua própria instância, substitua os marcadores de configuração:

- `YOUR_PROJECT_REF` pela referência do projeto Supabase.
- `YOUR_SUPABASE_PUBLISHABLE_KEY` pela Publishable Key do Supabase.
- `YOUR_ADMIN_EMAIL@example.com` pelo e-mail administrativo que você controla.

Esses marcadores aparecem no frontend e nos scripts SQL de instalação/migração. Não substitua-os por uma Secret Key ou service role key. A Publishable Key é pública; as políticas RLS são a principal barreira de segurança dos dados.

### Banco de dados

1. Crie um projeto Supabase.
2. No SQL Editor, execute `supabase/schema.sql`.
3. Configure Email Auth.
4. Para visitantes, habilite Anonymous Sign-Ins e aplique `supabase/migrations/20261106_guest_sessions_and_cleanup.sql`.
5. Aplique `supabase/migrations/20261106_review_sequence_admin_and_duplicate_decks.sql` quando indicado pelo fluxo de atualização.
6. Revise todas as políticas RLS antes de permitir cadastro público.

### IA

1. Gere uma chave no Google AI Studio.
2. Cadastre-a no Supabase como secret `GEMINI_API_KEY`.
3. Publique `supabase/functions/study-ai` com a Supabase CLI.
4. Nunca coloque a chave Gemini no frontend ou neste repositório.

Consulte `ATIVAR-IA.md` e `ATUALIZAR-PERFORMANCE.md`.

### Hospedagem

Publique `index.html`, `app.js` e `styles.css` no Cloudflare Pages. Não há etapa de build para o frontend estático.

## Regra de repetição espaçada

| Etapa | Próximo intervalo |
|---|---:|
| Cartão criado | Imediatamente disponível |
| Após a 1ª revisão | 24 horas |
| Após a 2ª revisão | 7 dias |
| Após a 3ª revisão | 15 dias |
| Após a 4ª revisão | 30 dias |
| Após a 5ª revisão | 60 dias |
| Após a 6ª e seguintes | 120 dias |

O cálculo parte do instante efetivo da revisão. A nota não altera a progressão; o nível vai até 6 e o contador de revisões continua aumentando.

## Testes

Com Node.js instalado:

```bash
node tests/scheduler.test.mjs
```

## Segurança e dados pessoais

- Nunca publique `.env`, tokens, `GEMINI_API_KEY`, Secret Key ou service role key.
- `YOUR_ADMIN_EMAIL@example.com` é um marcador: troque-o pelo e-mail que deverá ser administrador, inclusive nos scripts SQL relacionados à autorização.
- A Publishable Key e a URL do projeto são configuração pública, mas o projeto Supabase deve ter RLS corretamente configurado.
- Não inclua backups de banco de dados nem dados reais de usuários no repositório.
- Revise as políticas RLS, limites dos planos gratuitos, retenção de dados e backups antes de abrir a aplicação a outras pessoas.

## Estado

Projeto pessoal em evolução. O modo sem a função Gemini pode utilizar avaliação local demonstrativa, que não equivale à análise por IA. Os recursos externos dependem da configuração e dos limites dos respectivos serviços.
