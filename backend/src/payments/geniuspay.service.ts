import { BadRequestException, Injectable, ServiceUnavailableException } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { AppConfigService } from '../config/app-config.service';
import { SupabaseService } from '../supabase/supabase.service';
import { GeniusPayPaymentDto } from './geniuspay-payment.dto';

interface GeniusPayCreateResponse {
  success?: boolean;
  data?: {
    reference?: string;
    checkout_url?: string;
    payment_url?: string;
    status?: string;
  };
}

@Injectable()
export class GeniusPayService {
  constructor(
    private readonly config: AppConfigService,
    private readonly supabase: SupabaseService,
  ) {}

  async createPayment(userId: string, workspaceId: string | undefined, body: GeniusPayPaymentDto) {
    const apiKey = this.config.get('GENIUSPAY_API_KEY');
    const apiSecret = this.config.get('GENIUSPAY_API_SECRET');
    if (!apiKey || !apiSecret) {
      throw new ServiceUnavailableException('GeniusPay est indisponible.');
    }
    if (body.kind === 'SUBSCRIPTION' && (!body.subscriptionId || !workspaceId)) {
      throw new BadRequestException('Workspace et abonnement requis.');
    }
    if (body.subscriptionId && workspaceId) {
      await this.assertSubscriptionAccess(userId, workspaceId, body.subscriptionId);
    }
    const tokens =
      body.kind === 'AI_TOP_UP' ? body.amount * this.config.get('AI_TOKEN_MULTIPLIER') : undefined;

    const internalReference = `DEF-${randomUUID()}`;
    const { error: pendingError } = await this.supabase.admin.from('billing_payments').insert({
      user_id: userId,
      subscription_id: body.subscriptionId,
      amount: body.amount,
      currency: 'XOF',
      provider: 'GENIUSPAY',
      provider_reference: internalReference,
      status: 'PENDING',
      kind: body.kind,
    });
    if (pendingError) throw new BadRequestException('Paiement local impossible à enregistrer.');

    const response = await fetch(`${this.config.get('GENIUSPAY_API_URL')}/payments`, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-api-key': apiKey,
        'x-api-secret': apiSecret,
      },
      body: JSON.stringify({
        amount: body.amount,
        currency: 'XOF',
        description: body.description ?? 'DEFACT FACILE',
        metadata: {
          user_id: userId,
          kind: body.kind,
          subscription_id: body.subscriptionId ?? null,
          internal_reference: internalReference,
          tokens,
        },
      }),
    });
    if (!response.ok) throw new ServiceUnavailableException('GeniusPay a échoué.');

    const result = (await response.json()) as GeniusPayCreateResponse;
    const payment = result.data;
    const reference = payment?.reference;
    if (!result.success || !payment || !reference || !payment.checkout_url) {
      throw new BadRequestException('Réponse GeniusPay invalide.');
    }

    const { error } = await this.supabase.admin
      .from('billing_payments')
      .update({ provider_reference: reference })
      .eq('provider', 'GENIUSPAY')
      .eq('provider_reference', internalReference);
    if (error) throw new BadRequestException('Paiement local impossible à enregistrer.');

    return {
      reference,
      checkoutUrl: payment.checkout_url,
      paymentUrl: payment.payment_url ?? payment.checkout_url,
      status: payment.status ?? 'pending',
    };
  }

  private async assertSubscriptionAccess(
    userId: string,
    workspaceId: string,
    subscriptionId: string,
  ): Promise<void> {
    const { data: subscription, error } = await this.supabase.admin
      .from('subscriptions')
      .select('id, personal_workspace_id, organization_id')
      .eq('id', subscriptionId)
      .maybeSingle();
    if (error || !subscription) throw new BadRequestException('Abonnement introuvable.');
    if (subscription.personal_workspace_id && subscription.personal_workspace_id === workspaceId) {
      const { data: workspace } = await this.supabase.admin
        .from('personal_workspaces')
        .select('id')
        .eq('id', workspaceId)
        .eq('user_id', userId)
        .maybeSingle();
      if (workspace) return;
    }
    if (subscription.organization_id === workspaceId) {
      const { data: membership } = await this.supabase.admin
        .from('organization_members')
        .select('id')
        .eq('organization_id', workspaceId)
        .eq('user_id', userId)
        .eq('status', 'ACTIVE')
        .maybeSingle();
      if (membership) return;
    }
    throw new BadRequestException('Accès à cet abonnement refusé.');
  }
}
