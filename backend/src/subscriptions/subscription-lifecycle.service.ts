import { BadRequestException, Injectable } from '@nestjs/common';
import { GeniusPayService } from '../payments/geniuspay.service';
import { GeniusPayPaymentDto } from '../payments/geniuspay-payment.dto';
import { SupabaseService } from '../supabase/supabase.service';

@Injectable()
export class SubscriptionLifecycleService {
  constructor(
    private readonly supabase: SupabaseService,
    private readonly geniusPay: GeniusPayService,
  ) {}

  async expireDue(): Promise<{ expired: number }> {
    const { data, error } = await this.supabase.admin.rpc('expire_due_subscriptions');
    if (error) throw new BadRequestException('Expiration des abonnements impossible.');
    return { expired: typeof data === 'number' ? data : 0 };
  }

  async renew(userId: string, workspaceId: string | undefined, subscriptionId: string) {
    if (!workspaceId) throw new BadRequestException('X-Workspace-Id est requis.');
    const { data: subscription, error } = await this.supabase.admin
      .from('subscriptions')
      .select('id, status, billing_cycle, plans(price_monthly, price_yearly)')
      .eq('id', subscriptionId)
      .maybeSingle();
    if (error || !subscription) throw new BadRequestException('Abonnement introuvable.');
    if (!['EXPIRED', 'PAST_DUE'].includes(subscription.status)) {
      throw new BadRequestException('Cet abonnement ne nécessite pas encore de renouvellement.');
    }
    const plan = Array.isArray(subscription.plans) ? subscription.plans[0] : subscription.plans;
    const amount =
      subscription.billing_cycle === 'YEARLY' ? plan?.price_yearly : plan?.price_monthly;
    if (typeof amount !== 'number' || amount < 200) {
      throw new BadRequestException('Tarif de renouvellement invalide.');
    }
    const payment: GeniusPayPaymentDto = {
      amount,
      kind: 'SUBSCRIPTION',
      subscriptionId,
      description: 'Renouvellement DEFACT FACILE',
    };
    return this.geniusPay.createPayment(userId, workspaceId, payment);
  }
}
