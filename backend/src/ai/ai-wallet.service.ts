import { BadRequestException, Injectable, InternalServerErrorException } from '@nestjs/common';
import { SupabaseService } from '../supabase/supabase.service';
import { GeniusPayService } from '../payments/geniuspay.service';
import { AiCompletionResult } from './ai-provider';

@Injectable()
export class AiWalletService {
  constructor(
    private readonly supabase: SupabaseService,
    private readonly geniusPay: GeniusPayService,
  ) {}

  async balance(userId: string) {
    const { data, error } = await this.supabase.admin
      .from('ai_wallets')
      .select('balance, lifetime_credited, lifetime_consumed')
      .eq('user_id', userId)
      .maybeSingle();
    if (error) throw new InternalServerErrorException('Solde IA indisponible.');
    return {
      balance: data?.balance ?? 0,
      lifetimeCredited: data?.lifetime_credited ?? 0,
      lifetimeConsumed: data?.lifetime_consumed ?? 0,
    };
  }

  createTopUp(userId: string, amount: 1000 | 5000 | 10000 | 25000) {
    return this.geniusPay.createPayment(userId, undefined, {
      amount,
      kind: 'AI_TOP_UP',
      description: `Recharge wallet IA ${amount} XOF DEFACT FACILE`,
    });
  }

  async grantFreeBonus(userId: string): Promise<string> {
    const { data, error } = await this.supabase.admin.rpc('grant_free_ai_bonus', {
      p_user_id: userId,
    });
    if (error) throw new InternalServerErrorException(error.message);
    return data as string;
  }

  async reserve(
    userId: string,
    amount: number,
    action: string,
    provider: string,
    idempotencyKey: string,
    expiresAt: Date,
  ): Promise<string> {
    const { data, error } = await this.supabase.admin.rpc('reserve_ai_tokens', {
      p_user_id: userId,
      p_amount: amount,
      p_action: action,
      p_provider: provider,
      p_idempotency_key: idempotencyKey,
      p_expires_at: expiresAt.toISOString(),
    });
    if (error?.message.includes('quota insufficient')) {
      throw new BadRequestException('Quota IA insuffisant.');
    }
    if (error) throw new InternalServerErrorException(error.message);
    return data as string;
  }

  async complete(reservationId: string): Promise<boolean> {
    const { data, error } = await this.supabase.admin.rpc('complete_ai_reservation', {
      p_reservation_id: reservationId,
    });
    if (error) throw new InternalServerErrorException(error.message);
    return data as boolean;
  }

  async expire(reservationId: string): Promise<void> {
    const { error } = await this.supabase.admin.rpc('expire_ai_reservation', {
      p_reservation_id: reservationId,
    });
    if (error) throw new InternalServerErrorException(error.message);
  }

  async refund(reservationId: string): Promise<void> {
    const { error } = await this.supabase.admin.rpc('refund_ai_reservation', {
      p_reservation_id: reservationId,
    });
    if (error) throw new InternalServerErrorException(error.message);
  }

  async recordUsage(
    userId: string,
    reservationId: string,
    result: AiCompletionResult,
  ): Promise<void> {
    const { error } = await this.supabase.admin.from('ai_provider_usage').insert({
      user_id: userId,
      reservation_id: reservationId,
      provider: result.provider,
      model: result.model,
      input_tokens: result.inputTokens,
      output_tokens: result.outputTokens,
      cost_xof: result.costXof,
      succeeded: true,
    });
    if (error) throw new InternalServerErrorException(error.message);
  }

  async recordFailure(userId: string, reservationId: string, provider: string): Promise<void> {
    const { error } = await this.supabase.admin.from('ai_provider_usage').insert({
      user_id: userId,
      reservation_id: reservationId,
      provider,
      model: 'unknown',
      succeeded: false,
    });
    if (error) throw new InternalServerErrorException(error.message);
  }
}
