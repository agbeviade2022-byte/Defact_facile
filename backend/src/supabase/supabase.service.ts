import { Injectable } from '@nestjs/common';
import {
  createClient,
  RealtimeClientOptions,
  SupabaseClient,
  SupabaseClientOptions,
} from '@supabase/supabase-js';
import { WebSocket } from 'ws';
import { AppConfigService } from '../config/app-config.service';

// supabase-js requires a WebSocket transport at construction time; Node < 22 has none.
const serverOptions: SupabaseClientOptions<'public'> = {
  auth: { persistSession: false, autoRefreshToken: false },
  realtime: { transport: WebSocket as unknown as NonNullable<RealtimeClientOptions['transport']> },
};

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
      serverOptions,
    );
  }

  get admin(): SupabaseClient {
    return this.adminClient;
  }

  forUser(accessToken: string): SupabaseClient {
    return createClient(this.config.get('SUPABASE_URL'), this.config.get('SUPABASE_ANON_KEY'), {
      ...serverOptions,
      global: { headers: { Authorization: `Bearer ${accessToken}` } },
    });
  }
}
