# Memora

Plataforma de estudos com flashcards, repetição espaçada e apoio de inteligência artificial.

> Projeto pessoal desenvolvido com auxílio de ferramentas de IA (Vibe Coding). O objetivo é aprender, experimentar decisões de produto e evoluir uma aplicação real de forma incremental.

## Funcionalidades

- Autenticação de usuários com Supabase Auth.
- Organização em pastas, decks e cartões.
- Cartões discursivos e de múltipla escolha.
- Revisão imediata na criação; após a primeira revisão, intervalos de 24 horas, 7, 15, 30, 60 e 120 dias.
- Histórico de revisões e estado atual separados no PostgreSQL.
- Reformulação de enunciados e avaliação de respostas discursivas com Gemini por Supabase Edge Function.
- Área administrativa e configurações globais restritas.
- Modo visitante com autenticação anônima e limpeza por expiração.
- Interface responsiva hospedável no Cloudflare Pages.

## Tecnologias

- HTML, CSS e JavaScript
- Supabase (PostgreSQL, Auth, Row Level Security e Edge Functions)
- Google Gemini API
- Cloudflare Pages
- Supabase CLI

## Estrutura do projeto

A estrutura de aplicação, migrations, funções Edge e testes está incluída no pacote de código-fonte disponibilizado na seção de Releases/arquivos do repositório. Os arquivos SQL são aplicados no projeto Supabase; as chaves secretas permanecem somente nos Secrets do Supabase.

## Regras de revisão

| Momento | Próxima revisão |
|---|---:|
| Cartão recém-criado | Imediatamente |
| Após a 1ª revisão | 24 horas |
| Após a 2ª revisão | 7 dias |
| Após a 3ª revisão | 15 dias |
| Após a 4ª revisão | 30 dias |
| Após a 5ª revisão | 60 dias |
| Após a 6ª e seguintes | 120 dias |

O cálculo parte do instante real em que a revisão foi concluída. A nota não altera o intervalo. O nível vai de 0 a 6 e o contador de revisões continua crescendo.

## Configuração local

1. Clone o repositório.
2. Configure um projeto Supabase.
3. Aplique o schema inicial e as migrations em ordem.
4. Habilite Email Auth e, caso use o modo visitante, Anonymous Sign-Ins.
5. Configure `GEMINI_API_KEY` como secret no Supabase — nunca no frontend.
6. Publique as funções Edge necessárias com a Supabase CLI.
7. Publique os arquivos estáticos no Cloudflare Pages.

Consulte os documentos de configuração incluídos no projeto. Nunca publique `.env`, tokens de acesso, a chave Secret/service_role do Supabase ou a chave Gemini.

## Segurança

- O frontend usa apenas a Publishable Key do Supabase, que é uma chave pública.
- As tabelas devem manter Row Level Security (RLS) habilitado.
- Operações administrativas devem ser autorizadas no banco/backend, não apenas ocultadas na interface.
- A chave Gemini deve ficar nos Secrets da função Edge.
- Visitantes usam identidades anônimas isoladas e têm limpeza temporária configurada no banco.

Antes de abrir o projeto a novos usuários, revise as políticas RLS, os limites de uso dos serviços gratuitos e os procedimentos de backup.

## Estado do projeto

Projeto pessoal em evolução. Algumas experiências podem depender da configuração dos serviços externos e dos limites dos respectivos planos gratuitos. Avaliações locais de fallback não equivalem a uma avaliação feita pelo Gemini.

## Licença

MIT — consulte o arquivo LICENSE.
