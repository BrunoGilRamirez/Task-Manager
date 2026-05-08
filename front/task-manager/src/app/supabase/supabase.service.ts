import { Injectable } from '@angular/core';
import { createClient, SupabaseClient } from '@supabase/supabase-js';
import { environment } from '../core/environment';

/**
 * Provides a configured Supabase client instance for frontend auth and data access.
 */
@Injectable({
  providedIn: 'root',
})
export class SupabaseService {
  private supabase: SupabaseClient;

  constructor() {
    this.supabase = createClient(environment.supabaseUrl, environment.supabaseKey, {
      auth: {
        // Persist session per tab to balance UX and security.
        storage: sessionStorage,
        persistSession: true, // Persist sessions across reloads within the same tab.
        autoRefreshToken: true, // Automatically refresh tokens to maintain session without user intervention.
        detectSessionInUrl: true, // Enable detection of auth tokens in URL for seamless OAuth flows.
      },
    });
  }

  // Public getter to access the client (if needed)
  /**
   * Returns the shared Supabase client instance.
   */
  get client(): SupabaseClient {
    return this.supabase;
  }
}

export default SupabaseService;
