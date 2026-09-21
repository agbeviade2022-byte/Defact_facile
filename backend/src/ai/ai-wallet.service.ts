import { BadRequestException, Injectable, InternalServerErrorException } from '@nestjs/common';
import { SupabaseService } from '../supabase/supabase.service';

@Injectable()
export class AiWalletService {
  constructor(private readonly supabase: SupabaseService) {}

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

  async complete(reservationId: string): Promise<void> {
    const { error } = await this.supabase.admin.rpc('complete_ai_reservation', {
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
}
