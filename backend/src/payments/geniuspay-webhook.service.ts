import { BadRequestException, Injectable, UnauthorizedException } from '@nestjs/common';
import { createHmac, timingSafeEqual } from 'node:crypto';
import { AppConfigService } from '../config/app-config.service';
import { SupabaseService } from '../supabase/supabase.service';

@Injectable()
export class GeniusPayWebhookService {
  constructor(
    private readonly config: AppConfigService,
    private readonly supabase: SupabaseService,
  ) {}

  async handle(
    rawBody: string,
    signature: string | undefined,
    timestamp: string | undefined,
    event: string | undefined,
    environment?: string,
  ) {
    this.verifySignature(rawBody, signature, timestamp);
    const payload = this.parsePayload(rawBody);
    this.verifyEnvironment(environment, this.readString(payload, 'environment'));
    const data = this.readObject(payload, 'data');
    const metadata = this.readObject(data, 'metadata');
    const reference = this.readString(data, 'reference');
    const userId = this.readString(metadata, 'user_id');
    if (!reference || !userId) throw new BadRequestException('Webhook GeniusPay incomplet.');

    const eventName = event ?? this.readString(payload, 'event');
    const status = this.statusForEvent(eventName);
    const { data: existing, error: lookupError } = await this.supabase.admin
      .from('billing_payments')
      .select('id, status, provider_reference')
      .eq('provider', 'GENIUSPAY')
      .eq('provider_reference', reference)
      .maybeSingle();
    if (lookupError) throw new BadRequestException('Paiement GeniusPay introuvable.');
    if (existing && existing.status !== 'PENDING') {
      if (existing.status !== status) {
        throw new BadRequestException('Transition de paiement GeniusPay contradictoire.');
      }
      return { received: true, payment: existing };
    }

    const { data: payment, error } = await this.supabase.admin
      .from('billing_payments')
      .upsert(
        {
          user_id: userId,
          amount: this.readNumber(data, 'amount') ?? 0,
          currency: this.readString(data, 'currency') ?? 'XOF',
          provider: 'GENIUSPAY',
          provider_reference: reference,
          status,
          kind: this.readString(metadata, 'kind') === 'AI_TOP_UP' ? 'AI_TOP_UP' : 'SUBSCRIPTION',
          subscription_id: this.readString(metadata, 'subscription_id'),
          confirmed_at: status === 'SUCCEEDED' ? new Date().toISOString() : null,
        },
        { onConflict: 'provider,provider_reference' },
      )
      .select('id, status, provider_reference')
      .single();

    if (error) throw new BadRequestException('Webhook GeniusPay invalide.');
    if (status === 'SUCCEEDED') {
      const subscriptionId = this.readString(metadata, 'subscription_id');
      if (subscriptionId) {
        await this.supabase.admin
          .from('subscriptions')
          .update({
            status: 'ACTIVE',
            payment_reference: reference,
            current_period_start: new Date().toISOString(),
          })
          .eq('id', subscriptionId)
          .eq('status', 'TRIALING');
      }
    }
    return { received: true, payment };
  }

  private verifySignature(
    rawBody: string,
    signature: string | undefined,
    timestamp: string | undefined,
  ): void {
    const secret = this.config.get('GENIUSPAY_WEBHOOK_SECRET');
    if (!secret || !signature || !timestamp) {
      throw new UnauthorizedException('Signature GeniusPay invalide.');
    }
    const timestampNumber = Number(timestamp);
    if (!Number.isInteger(timestampNumber) || Math.abs(Date.now() / 1000 - timestampNumber) > 300) {
      throw new UnauthorizedException('Webhook GeniusPay expiré.');
    }
    const expected = createHmac('sha256', secret).update(`${timestamp}.${rawBody}`).digest('hex');
    const received = Buffer.from(signature, 'utf8');
    const calculated = Buffer.from(expected, 'utf8');
    if (received.length !== calculated.length || !timingSafeEqual(received, calculated)) {
      throw new UnauthorizedException('Signature GeniusPay invalide.');
    }
  }

  private statusForEvent(
    event: string | undefined,
  ): 'PENDING' | 'SUCCEEDED' | 'FAILED' | 'CANCELLED' {
    if (event === 'payment.success') return 'SUCCEEDED';
    if (event === 'payment.failed') return 'FAILED';
    if (
      event === 'payment.cancelled' ||
      event === 'payment.expired' ||
      event === 'payment.refunded'
    ) {
      return 'CANCELLED';
    }
    throw new BadRequestException('Événement GeniusPay non supporté.');
  }

  private verifyEnvironment(header: string | undefined, payload: string | undefined): void {
    const received = header ?? payload;
    if (!received) return;
    const expected = this.config.get('GENIUSPAY_SANDBOX') === 'true' ? 'sandbox' : 'live';
    if (received !== expected || (header && payload && header !== payload)) {
      throw new BadRequestException('Environnement GeniusPay invalide.');
    }
  }

  private parsePayload(rawBody: string): Record<string, unknown> {
    const parsed: unknown = JSON.parse(rawBody);
    if (!this.isRecord(parsed)) throw new BadRequestException('Payload GeniusPay invalide.');
    return parsed;
  }

  private readObject(value: unknown, key: string): Record<string, unknown> {
    if (!this.isRecord(value) || !this.isRecord(value[key])) return {};
    return value[key];
  }

  private readString(value: unknown, key: string): string | undefined {
    if (!this.isRecord(value) || typeof value[key] !== 'string') return undefined;
    return value[key];
  }

  private readNumber(value: unknown, key: string): number | undefined {
    if (!this.isRecord(value) || typeof value[key] !== 'number') return undefined;
    return value[key];
  }

  private isRecord(value: unknown): value is Record<string, unknown> {
    return typeof value === 'object' && value !== null && !Array.isArray(value);
  }
}
