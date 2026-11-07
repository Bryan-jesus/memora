# Security policy

## Reporting a vulnerability

Do not publish credentials, personal data, or exploit details in a public issue. Contact the repository owner privately through GitHub.

## Secrets

Never commit `.env` files, access tokens, Gemini API keys, Supabase Secret keys, or service role keys. Use Supabase Edge Function secrets for server-side credentials.

The public Supabase Publishable Key is intentionally a frontend configuration value; it must be protected by correctly configured Row Level Security policies.
