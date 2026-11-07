# Ativar o modo visitante

## 1. Habilitar no Supabase Auth

No Supabase Dashboard, abra **Authentication → Sign In / Providers** e habilite **Allow anonymous sign-ins**. O modo visitante usa a autenticação anônima nativa do Supabase.

## 2. Instalar o controle de expiração

Abra **Integrations → Cron** e confirme que `pg_cron` está habilitado. Depois abra **SQL Editor → New query**, cole e execute todo o arquivo `supabase/migrations/20261106_guest_sessions_and_cleanup.sql`.

A migration cria uma tabela privada para sessões temporárias, um heartbeat que renova a sessão enquanto a aba está ativa e um job que remove usuários anônimos expirados. Os dados associados são removidos por `ON DELETE CASCADE`.

## 3. Publicar a função de remoção imediata

Na raiz do projeto (a pasta que contém `supabase/`), execute:

```powershell
npx supabase link --project-ref YOUR_PROJECT_REF
npx supabase functions deploy guest-cleanup
```

A função valida o JWT e só permite excluir o próprio usuário quando `is_anonymous=true`. Ela usa a chave Secret/Service Role somente no ambiente da Edge Function, nunca no frontend.

## Comportamento da sessão visitante

- O visitante não precisa informar e-mail nem senha.
- O Supabase cria um usuário anônimo com seus próprios dados isolados pelas políticas RLS.
- A sessão do navegador fica em `sessionStorage`, portanto não é restaurada como uma conta comum quando a aba/navegador é fechado.
- Ao fechar a aba/navegador, o `sessionStorage` desaparece e a sessão visitante não pode ser restaurada.
- O servidor expira a conta após uma hora sem heartbeat, e o Cron verifica a cada 15 minutos. Assim, a conta e seus dados são eliminados em até aproximadamente 1h15.
- O botão de encerramento no aplicativo solicita a remoção imediata enquanto a sessão ainda está aberta.

A remoção automática usa expiração no servidor porque o navegador não oferece garantia de que uma chamada de rede termine durante o fechamento da janela.
