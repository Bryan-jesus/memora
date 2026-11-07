# Ativar a IA do Memora

1. Gere uma chave pessoal em https://aistudio.google.com/app/apikey.
2. Instale Node.js e a Supabase CLI.
3. Abra um terminal na pasta do projeto (onde está `supabase/`).
4. Execute:

```bash
npm install -g supabase
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase secrets set GEMINI_API_KEY="SUA_CHAVE_GEMINI"
supabase functions deploy study-ai
```

O `PROJECT_REF` é o subdomínio da URL do Supabase, sem `.supabase.co`.

A chave deve ficar como secret no Supabase. Não a coloque no HTML, JavaScript do navegador ou Cloudflare Pages como variável pública.

Após publicar, entre no Memora com a conta administrativa configurada no schema e abra **Controle interno** para confirmar o status da IA.

A cada revisão, a IA recebe o nível e as últimas revisões do cartão para criar uma formulação diferente sem alterar o conceito ou a dificuldade. Na revisão discursiva, analisa a resposta em comparação com o gabarito cadastrado no cartão, ignorando erros de digitação e aceitando explicações equivalentes. A resposta retorna nota de 0 a 5 e feedback curto.

Se a função ou a chave não estiverem configuradas, o aplicativo usa o modo local demonstrativo.
