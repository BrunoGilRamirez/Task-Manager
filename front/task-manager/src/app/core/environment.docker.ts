// Configuración del frontend cuando se usa el stack local de Docker.
// Para activarla, copia este contenido en src/app/core/environment.ts
// (o configura Angular para usar este archivo en el build).
//
// SUPABASE_URL  → http://localhost:54321  (Kong API Gateway del docker-compose)
// supabaseKey   → ANON_KEY de docker/.env

export const environment = {
  production: false,
  supabaseUrl: 'http://localhost:5433',
  supabaseKey:
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.b_lMH2mc5km7S9Lw_sRGGqE9IeiahYu-caevDcacKiY',
  backendUrl: 'http://localhost:3000',
};
