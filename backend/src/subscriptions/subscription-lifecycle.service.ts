import { BadRequestException, Injectable } from '@nestjs/common';
import { GeniusPayService } from '../payments/geniuspay.service';
import { GeniusPayPaymentDto } from '../payments/geniuspay-payment.dto';
import { SupabaseService } from '../supabase/supabase.service';
import { StartSubscriptionDto } from './start-subscription.dto';

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

  async start(userId: string, workspaceId: string | undefined, input: StartSubscriptionDto) {
    if (!workspaceId) throw new BadRequestException('X-Workspace-Id est requis.');

    const { data: plan, error: planError } = await this.supabase.admin
      .from('plans')
      .select('id, name, audience, price_monthly, price_yearly, is_active')
      .eq('id', input.planId)
      .eq('is_active', true)
      .maybeSingle();
    if (planError || !plan) throw new BadRequestException('Forfait introuvable.');

    const workspace = await this.resolveWorkspace(userId, workspaceId);
    if (
      plan.audience !== 'BOTH' &&
      plan.audience !== (workspace.kind === 'personal' ? 'PERSONAL' : 'ORGANIZATION')
    ) {
      throw new BadRequestException('Ce forfait ne correspond pas à cet espace.');
    }

    const amount =
      input.billingCycle === 'YEARLY' ? Number(plan.price_yearly) : Number(plan.price_monthly);
    if (amount < 200) {
      throw new BadRequestException('Ce forfait ne nécessite pas de paiement.');
    }

    const workspaceColumn =
      workspace.kind === 'personal' ? 'personal_workspace_id' : 'organization_id';
    const { data: existing, error: existingError } = await this.supabase.admin
      .from('subscriptions')
      .select('id, status')
      .eq(workspaceColumn, workspaceId)
      .maybeSingle();
    if (existingError) throw new BadRequestException('Abonnement indisponible.');
    if (existing?.status === 'ACTIVE') {
      throw new BadRequestException('Cet espace possède déjà un abonnement actif.');
    }

    let subscriptionId = existing?.id;
    if (subscriptionId) {
      const { error } = await this.supabase.admin
        .from('subscriptions')
        .update({ plan_id: input.planId, billing_cycle: input.billingCycle, status: 'TRIALING' })
        .eq('id', subscriptionId);
      if (error) throw new BadRequestException('Abonnement impossible à préparer.');
    } else {
      const { data: subscription, error } = await this.supabase.admin
        .from('subscriptions')
        .insert({
          [workspaceColumn]: workspaceId,
          plan_id: input.planId,
          billing_cycle: input.billingCycle,
          status: 'TRIALING',
        })
        .select('id')
        .single();
      if (error || !subscription) {
        throw new BadRequestException('Abonnement impossible à préparer.');
      }
      subscriptionId = subscription.id;
    }

    const payment: GeniusPayPaymentDto = {
      amount,
      kind: 'SUBSCRIPTION',
      subscriptionId,
      description: `Abonnement ${plan.name} DEFACT FACILE`,
    };
    const checkout = await this.geniusPay.createPayment(userId, workspaceId, payment);
    return { subscriptionId, ...checkout };
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

  private async resolveWorkspace(userId: string, workspaceId: string) {
    const { data: personal } = await this.supabase.admin
      .from('personal_workspaces')
      .select('id')
      .eq('id', workspaceId)
      .eq('user_id', userId)
      .maybeSingle();
    if (personal) return { kind: 'personal' as const };

    const { data: membership } = await this.supabase.admin
      .from('organization_members')
      .select('id')
      .eq('organization_id', workspaceId)
      .eq('user_id', userId)
      .eq('status', 'ACTIVE')
      .maybeSingle();
    if (membership) return { kind: 'organization' as const };

    throw new BadRequestException('Workspace inaccessible.');
  }
}
