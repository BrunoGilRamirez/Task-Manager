// Frontend configuration when using the local Docker stack.
// To enable, copy this content into src/app/core/environment.ts
// (or configure Angular to use this file in the build).
//
// SUPABASE_URL  → http://localhost:54321  (Kong API Gateway from docker-compose)
// supabaseKey   → ANON_KEY from docker/.env

export const environment = {
  production: false,
  supabaseUrl: 'http://localhost:5433',
  supabaseKey:
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.b_lMH2mc5km7S9Lw_sRGGqE9IeiahYu-caevDcacKiY',
  backendUrl: 'http://localhost:3000',
};
