# Memora — desempenho da IA

A função Edge usa `gemini-3.5-flash-lite` com configuração de baixa latência.

## Otimizações

- Prompt de avaliação curto, mantendo os critérios e a escala de 0 a 5.
- `thinkingConfig.thinkingLevel = MINIMAL` nas tarefas de reformulação e avaliação.
- JWT verificado pelo gateway Supabase (`verify_jwt = true`).
- Métricas de latência do provedor e da chamada completa no resultado da avaliação.
- Logs limitados a ação, modelo, duração e contagem de tokens; perguntas, gabaritos e respostas não são registrados.

## Implantação

Na pasta principal do projeto (aquela que contém `supabase/`), execute:

```powershell
npx supabase functions deploy study-ai
```

Não é necessário alterar a `GEMINI_API_KEY` nem executar migrations SQL.

## Segurança

O gateway Supabase deve continuar com `verify_jwt = true`. Não use `--no-verify-jwt`, não publique a `GEMINI_API_KEY` no frontend e não compartilhe tokens/chaves.
