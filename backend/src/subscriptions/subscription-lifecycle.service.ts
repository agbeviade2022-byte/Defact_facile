import { Injectable, BadRequestException } from '@nestjs/common';
import { SupabaseService } from '../supabase/supabase.service';

@Injectable()
export class SubscriptionLifecycleService {
  constructor(private readonly supabase: SupabaseService) {}

  async expireDue(): Promise<{ expired: number }> {
    const { data, error } = await this.supabase.admin.rpc('expire_due_subscriptions');
    if (error) throw new BadRequestException('Expiration des abonnements impossible.');
    return { expired: typeof data === 'number' ? data : 0 };
  }
}
