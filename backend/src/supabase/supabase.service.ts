import { Injectable } from '@nestjs/common';
import { createClient, SupabaseClient } from '@supabase/supabase-js';
import { AppConfigService } from '../config/app-config.service';

/**
 * Two kinds of clients:
 * - `admin`: service-role client, bypasses RLS. Only for trusted server code
 *   that has already enforced tenant + permission checks.
 * - `forUser(jwt)`: anon client carrying the end-user JWT, so RLS applies as a
 *   second line of defence.
 */
@Injectable()
export class SupabaseService {
  private readonly adminClient: SupabaseClient;

  constructor(private readonly config: AppConfigService) {
    this.adminClient = createClient(
      config.get('SUPABASE_URL'),
      config.get('SUPABASE_SERVICE_ROLE_KEY'),
      { auth: { persistSession: false, autoRefreshToken: false } },
    );
  }

  get admin(): SupabaseClient {
    return this.adminClient;
  }

  forUser(accessToken: string): SupabaseClient {
    return createClient(this.config.get('SUPABASE_URL'), this.config.get('SUPABASE_ANON_KEY'), {
      auth: { persistSession: false, autoRefreshToken: false },
      global: { headers: { Authorization: `Bearer ${accessToken}` } },
    });
  }
}
