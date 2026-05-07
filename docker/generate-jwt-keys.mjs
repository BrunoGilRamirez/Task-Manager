#!/usr/bin/env node
// =============================================================================
// Generador de JWT Keys para el stack local de Supabase
//
// Uso:
//   node docker/generate-jwt-keys.mjs [tu-jwt-secret]
//
// Si no se pasa argumento, usa el secret por defecto del .env.example.
// Copia los valores generados a docker/.env (ANON_KEY y SERVICE_ROLE_KEY).
// =============================================================================

import { createHmac } from 'crypto';

const secret = process.argv[2] ??
  'your-super-secret-jwt-token-with-at-least-32-characters-long';

if (secret.length < 32) {
  console.error('❌  El JWT_SECRET debe tener al menos 32 caracteres.');
  process.exit(1);
}

function base64url(input) {
  return Buffer.from(input).toString('base64')
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
}

function makeJwt(payload) {
  const header  = base64url(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
  const body    = base64url(JSON.stringify(payload));
  const sig     = createHmac('sha256', secret)
    .update(`${header}.${body}`)
    .digest('base64')
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
  return `${header}.${body}.${sig}`;
}

// exp: año 2032 (unix timestamp)
const exp = 1983812996;

const anonKey        = makeJwt({ iss: 'supabase-demo', role: 'anon',         exp });
const serviceRoleKey = makeJwt({ iss: 'supabase-demo', role: 'service_role', exp });

console.log('\n── JWT Keys generadas ─────────────────────────────────────────────');
console.log(`JWT_SECRET=${secret}\n`);
console.log(`ANON_KEY=${anonKey}\n`);
console.log(`SERVICE_ROLE_KEY=${serviceRoleKey}\n`);
console.log('Pega estos valores en docker/.env y en:');
console.log('  back/task-manager/.env  →  SUPABASE_PUBLISHABLE_KEY=<ANON_KEY>');
console.log('  front/task-manager/src/app/core/environment.ts  →  supabaseKey: "<ANON_KEY>"');
