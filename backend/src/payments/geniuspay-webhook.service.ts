import { BadRequestException, Injectable, UnauthorizedException } from '@nestjs/common';
import { createHmac, timingSafeEqual } from 'node:crypto';
import { AppConfigService } from '../config/app-config.service';
import { SupabaseService } from '../supabase/supabase.service';
import { GeniusPayWebhookDto } from './geniuspay-webhook.dto';

@Injectable()
export class GeniusPayWebhookService {
  constructor(
    private readonly config: AppConfigService,
    private readonly supabase: SupabaseService,
  ) {}

  async handle(payload: GeniusPayWebhookDto, signature: string | undefined) {
    this.verifySignature(payload, signature);

    const { data, error } = await this.supabase.admin
      .from('billing_payments')
      .upsert(
        {
          user_id: payload.userId,
          amount: payload.amount,
          currency: payload.currency,
          provider: 'GENIUSPAY',
          provider_reference: payload.providerReference,
          status: payload.status,
          kind: payload.kind,
          subscription_id: payload.subscriptionId,
          confirmed_at: payload.status === 'SUCCEEDED' ? new Date().toISOString() : null,
        },
        { onConflict: 'provider,provider_reference' },
      )
      .select('id, status, provider_reference')
      .single();

    if (error) throw new BadRequestException('Webhook GeniusPay invalide.');
    return { received: true, payment: data };
  }

  private verifySignature(payload: GeniusPayWebhookDto, signature: string | undefined): void {
    const secret = this.config.get('GENIUSPAY_WEBHOOK_SECRET');
    if (!secret || !signature) throw new UnauthorizedException('Signature GeniusPay invalide.');

    const expected = createHmac('sha256', secret).update(JSON.stringify(payload)).digest('hex');
    const received = Buffer.from(signature, 'utf8');
    const calculated = Buffer.from(expected, 'utf8');
    if (received.length !== calculated.length || !timingSafeEqual(received, calculated)) {
      throw new UnauthorizedException('Signature GeniusPay invalide.');
    }
  }
}
